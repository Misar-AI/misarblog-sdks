package blog.misar.sdk;

import blog.misar.sdk.models.Article;
import com.sun.net.httpserver.HttpServer;
import org.junit.jupiter.api.Test;

import java.io.IOException;
import java.io.OutputStream;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.util.Map;
import java.util.concurrent.atomic.AtomicInteger;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Uses the JDK's built-in {@link HttpServer} so the test needs no HTTP-mock
 * dependency.
 */
class MisarBlogTest {

    private record Server(HttpServer server, String baseUrl) {}

    private Server start(com.sun.net.httpserver.HttpHandler handler) throws IOException {
        HttpServer s = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        s.createContext("/", handler);
        s.start();
        return new Server(s, "http://127.0.0.1:" + s.getAddress().getPort());
    }

    private static void respond(com.sun.net.httpserver.HttpExchange ex, int code, String body) throws IOException {
        byte[] b = body.getBytes(StandardCharsets.UTF_8);
        ex.getResponseHeaders().add("Content-Type", "application/json");
        ex.sendResponseHeaders(code, b.length);
        try (OutputStream os = ex.getResponseBody()) {
            os.write(b);
        }
    }

    @Test
    void getArticleIsTyped() throws Exception {
        Server srv = start(ex -> {
            assertEquals("Bearer mbk_test", ex.getRequestHeaders().getFirst("Authorization"));
            respond(ex, 200, "{\"id\":\"a1\",\"slug\":\"hello\",\"title\":\"Hello\",\"status\":\"published\"," +
                    "\"url\":\"u\",\"editor_url\":\"e\",\"tags\":[\"java\"]}");
        });
        try {
            MisarBlog blog = new MisarBlog.Builder("mbk_test").baseUrl(srv.baseUrl()).build();
            Article a = blog.articles.get("hello");
            assertEquals("hello", a.slug);
            assertEquals("e", a.editorUrl);
            assertEquals("java", a.tags.get(0));
        } finally {
            srv.server().stop(0);
        }
    }

    @Test
    void errorEnvelopeIsParsed() throws Exception {
        Server srv = start(ex -> respond(ex, 401, "{\"error\":\"missing key\"}"));
        try {
            MisarBlog blog = new MisarBlog.Builder("mbk_test").baseUrl(srv.baseUrl()).build();
            BlogApiException e = assertThrows(BlogApiException.class, () -> blog.account.me());
            assertEquals(401, e.getStatus());
            assertTrue(e.getMessage().contains("missing key"));
        } finally {
            srv.server().stop(0);
        }
    }

    @Test
    void retriesThenSucceeds() throws Exception {
        AtomicInteger calls = new AtomicInteger();
        Server srv = start(ex -> {
            if (calls.getAndIncrement() == 0) {
                respond(ex, 503, "{\"error\":\"try later\"}");
            } else {
                respond(ex, 200, "{\"plan\":\"pro\"}");
            }
        });
        try {
            MisarBlog blog = new MisarBlog.Builder("mbk_test").baseUrl(srv.baseUrl()).maxRetries(3).build();
            Map<String, Object> plan = blog.plan.get();
            assertEquals("pro", plan.get("plan"));
            assertEquals(2, calls.get());
        } finally {
            srv.server().stop(0);
        }
    }

    @Test
    void sendsOnFinalAttemptNoOffByOne() throws Exception {
        // Always 429. With maxRetries=2 the server must see exactly 2 requests and
        // the surfaced error must carry the real 429 body — proving the final
        // attempt was actually sent (no off-by-one that skips it).
        AtomicInteger calls = new AtomicInteger();
        Server srv = start(ex -> {
            calls.incrementAndGet();
            respond(ex, 429, "{\"error\":\"rate limited\"}");
        });
        try {
            MisarBlog blog = new MisarBlog.Builder("mbk_test").baseUrl(srv.baseUrl()).maxRetries(2).build();
            BlogApiException e = assertThrows(BlogApiException.class, () -> blog.plan.get());
            assertEquals(429, e.getStatus());
            assertTrue(e.getMessage().contains("rate limited"));
            assertEquals(2, calls.get());
        } finally {
            srv.server().stop(0);
        }
    }

    @Test
    void embedUrlBuildsCorrectly() {
        assertEquals("https://misar.blog/alice/embed", MisarBlog.embedUrl("alice", null, "auto"));
        assertEquals("https://misar.blog/alice/my-post/embed?theme=dark",
                MisarBlog.embedUrl("alice", "my-post", "dark"));
    }
}
