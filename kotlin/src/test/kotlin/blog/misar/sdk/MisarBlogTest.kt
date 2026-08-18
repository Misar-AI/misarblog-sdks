package blog.misar.sdk

import com.sun.net.httpserver.HttpExchange
import com.sun.net.httpserver.HttpHandler
import com.sun.net.httpserver.HttpServer
import kotlinx.coroutines.runBlocking
import java.net.InetSocketAddress
import java.nio.charset.StandardCharsets
import java.util.concurrent.atomic.AtomicInteger
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertTrue

/** Uses the JDK's built-in [HttpServer] so the tests need no HTTP-mock dependency. */
class MisarBlogTest {

    private fun server(handler: (HttpExchange) -> Unit): Pair<HttpServer, String> {
        val s = HttpServer.create(InetSocketAddress("127.0.0.1", 0), 0)
        s.createContext("/", HttpHandler { handler(it) })
        s.start()
        return s to "http://127.0.0.1:${s.address.port}"
    }

    private fun respond(ex: HttpExchange, code: Int, body: String) {
        val b = body.toByteArray(StandardCharsets.UTF_8)
        ex.responseHeaders.add("Content-Type", "application/json")
        ex.sendResponseHeaders(code, b.size.toLong())
        ex.responseBody.use { it.write(b) }
    }

    @Test
    fun getArticleIsTyped() {
        val (s, url) = server { ex ->
            assertEquals("Bearer mbk_test", ex.requestHeaders.getFirst("Authorization"))
            respond(ex, 200, """{"id":"a1","slug":"hello","title":"Hello","status":"published",
                |"url":"u","editor_url":"e","tags":["kotlin"]}""".trimMargin())
        }
        try {
            val blog = MisarBlog("mbk_test", baseUrl = url)
            val a = runBlocking { blog.articles.get("hello") }
            assertEquals("hello", a.slug)
            assertEquals("e", a.editorUrl)
            assertEquals("kotlin", a.tags[0])
        } finally {
            s.stop(0)
        }
    }

    @Test
    fun errorEnvelopeIsParsed() {
        val (s, url) = server { ex -> respond(ex, 401, """{"error":"missing key"}""") }
        try {
            val blog = MisarBlog("mbk_test", baseUrl = url)
            val e = assertFailsWith<BlogApiException> { runBlocking { blog.account.me() } }
            assertEquals(401, e.status)
            assertTrue(e.message!!.contains("missing key"))
        } finally {
            s.stop(0)
        }
    }

    @Test
    fun retriesThenSucceeds() {
        val calls = AtomicInteger()
        val (s, url) = server { ex ->
            if (calls.getAndIncrement() == 0) respond(ex, 503, """{"error":"try later"}""")
            else respond(ex, 200, """{"plan":"pro"}""")
        }
        try {
            val blog = MisarBlog("mbk_test", baseUrl = url, maxRetries = 3)
            val plan = runBlocking { blog.plan.get() }
            assertEquals("pro", plan["plan"])
            assertEquals(2, calls.get())
        } finally {
            s.stop(0)
        }
    }

    @Test
    fun sendsOnFinalAttemptNoOffByOne() {
        // Always 429. With maxRetries=2 the server must see exactly 2 requests and
        // the surfaced error carries the real 429 body — proving the final attempt
        // was actually sent.
        val calls = AtomicInteger()
        val (s, url) = server { ex ->
            calls.incrementAndGet()
            respond(ex, 429, """{"error":"rate limited"}""")
        }
        try {
            val blog = MisarBlog("mbk_test", baseUrl = url, maxRetries = 2)
            val e = assertFailsWith<BlogApiException> { runBlocking { blog.plan.get() } }
            assertEquals(429, e.status)
            assertTrue(e.message!!.contains("rate limited"))
            assertEquals(2, calls.get())
        } finally {
            s.stop(0)
        }
    }

    @Test
    fun embedUrlBuildsCorrectly() {
        assertEquals("https://misar.blog/alice/embed", MisarBlog.embedUrl("alice"))
        assertEquals(
            "https://misar.blog/alice/my-post/embed?theme=dark",
            MisarBlog.embedUrl("alice", "my-post", "dark"),
        )
    }
}
