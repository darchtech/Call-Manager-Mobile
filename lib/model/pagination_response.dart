class PaginationResponse<T> {
  final List<T> results;
  final int page;
  final int limit;
  final int totalResults;
  final int totalPages;

  PaginationResponse({
    required this.results,
    required this.page,
    required this.limit,
    required this.totalResults,
    required this.totalPages,
  });

  factory PaginationResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJsonT,
  ) {
    return PaginationResponse<T>(
      results: (json['results'] as List<dynamic>)
          .map((item) => fromJsonT(item as Map<String, dynamic>))
          .toList(),
      page: json['page'] ?? 1,
      limit: json['limit'] ?? 10,
      totalResults: json['totalResults'] ?? 0,
      totalPages: json['totalPages'] ?? 1,
    );
  }

  Map<String, dynamic> toJson(Map<String, dynamic> Function(T) toJsonT) {
    return {
      'results': results.map((item) => toJsonT(item)).toList(),
      'page': page,
      'limit': limit,
      'totalResults': totalResults,
      'totalPages': totalPages,
    };
  }

  bool get hasNextPage => page < totalPages;
  bool get hasPreviousPage => page > 1;
  bool get isEmpty => results.isEmpty;
  bool get isNotEmpty => results.isNotEmpty;

  @override
  String toString() {
    return 'PaginationResponse(page: $page, limit: $limit, totalResults: $totalResults, totalPages: $totalPages, results: ${results.length} items)';
  }
}
