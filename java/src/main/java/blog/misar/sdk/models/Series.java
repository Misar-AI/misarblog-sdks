package blog.misar.sdk.models;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonProperty;

/**
 * A series (collection) of articles.
 */
@JsonIgnoreProperties(ignoreUnknown = true)
public class Series {
    public String id;
    public String slug;
    public String title;
    public String description;

    @JsonProperty("article_count")
    public int articleCount;

    @JsonProperty("created_at")
    public String createdAt;

    @Override
    public String toString() {
        return "Series{slug=" + slug + ", title=" + title + ", articleCount=" + articleCount + "}";
    }
}
