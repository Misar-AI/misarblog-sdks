const String embedBase = "https://misar.blog";

String embedUrl(String username, {String? slug, String theme = "auto"}) {
  final path = slug != null ? "$username/$slug/embed" : "$username/embed";
  final base = "$embedBase/$path";
  return theme != "auto" ? "$base?theme=$theme" : base;
}
