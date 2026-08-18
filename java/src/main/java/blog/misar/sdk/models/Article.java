package blog.misar.sdk.models;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonProperty;

import java.util.List;

/**
 * A blog article as returned by the publish/draft/get/update endpoints.
 */
@JsonIgnoreProperties(ignoreUnknown = true)
public class Article {
    public String id;
    public String slug;
    public String title;
    public String status;
    public String url;

    @JsonProperty("editor_url")
    public String editorUrl;

    public String excerpt;
    public List<String> tags;
    public String visibility;

    @JsonProperty("published_at")
    public String publishedAt;

    @JsonProperty("created_at")
    public String createdAt;

    @Override
    public String toString() {
        return "Article{slug=" + slug + ", title=" + title + ", status=" + status + "}";
    }
}
