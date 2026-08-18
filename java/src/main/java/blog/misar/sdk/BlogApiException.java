package blog.misar.sdk;

/**
 * Thrown when the Misar.Blog API returns a non-2xx HTTP response, or when a
 * network-level error prevents the request from completing.
 *
 * <p>For network errors (and exhausted retries) the {@code status} is {@code 0}.
 * The {@code message} is extracted from the standard {@code {"error": ...}}
 * envelope when present.
 */
public class BlogApiException extends Exception {

    private final int status;

    /**
     * @param status  HTTP status code (0 for network errors).
     * @param message Human-readable description.
     */
    public BlogApiException(int status, String message) {
        super("BlogApiException(" + status + "): " + message);
        this.status = status;
    }

    /**
     * @param status  HTTP status code (0 for network errors).
     * @param message Human-readable description.
     * @param cause   Underlying throwable.
     */
    public BlogApiException(int status, String message, Throwable cause) {
        super("BlogApiException(" + status + "): " + message, cause);
        this.status = status;
    }

    /** HTTP status code returned by the server, or {@code 0} for network errors. */
    public int getStatus() {
        return status;
    }
}
