use serde::{Deserialize, Serialize};

const EMBED_BASE: &str = "https://misar.blog";

#[derive(Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct TokenResult {
    pub token: String,
    pub expires_at: i64,
}

#[derive(Serialize)]
struct RefreshRequest<'a> {
    token: &'a str,
}

pub fn embed_url(username: &str, slug: Option<&str>, theme: &str) -> String {
    let path = match slug {
        Some(s) => format!("{}/{}/embed", username, s),
        None => format!("{}/embed", username),
    };
    if theme != "auto" {
        format!("{}/{}?theme={}", EMBED_BASE, path, theme)
    } else {
        format!("{}/{}", EMBED_BASE, path)
    }
}

pub async fn refresh_token(token: &str, base_url: &str) -> Result<TokenResult, reqwest::Error> {
    let client = reqwest::Client::new();
    let result = client
        .post(format!("{}/api/auth/refresh", base_url))
        .json(&RefreshRequest { token })
        .send()
        .await?
        .error_for_status()?
        .json::<TokenResult>()
        .await?;
    Ok(result)
}
