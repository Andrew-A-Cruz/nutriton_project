/// Catalog search rules, shared by the SQL food search and the in-memory meal
/// filter so both match the same way.
library;

/// The words of [query], lower-cased. Each must appear somewhere in a match,
/// in any order: "chick breast" finds "Chicken breast, grilled".
List<String> searchWords(String query) => [
  for (final word in query.toLowerCase().split(RegExp(r'\s+')))
    if (word.isNotEmpty) word,
];

/// Whether every word of [query] appears in one of [fields] (case-insensitive).
/// An empty query matches everything.
bool matchesSearch(String query, Iterable<String?> fields) {
  final haystack = [
    for (final f in fields)
      if (f != null) f.toLowerCase(),
  ].join(' ');
  return searchWords(query).every(haystack.contains);
}
