
class ApiResponse<T> {
  final bool success;
  final T? data;
  final String? error;
  final int statusCode;

  ApiResponse({
    required this.success,
    this.data,
    this.error,
    required this.statusCode,
  });

  bool get isSuccess => success && data != null;
  bool get isError => !success || error != null;

  // Map the data to another type while preserving success/error state
  ApiResponse<R> map<R>(R Function(T data) transform) {
    if (data != null) {
      return ApiResponse<R>(
        success: success,
        data: transform(data!),
        error: error,
        statusCode: statusCode,
      );
    }
    return ApiResponse<R>(
      success: success,
      data: null,
      error: error,
      statusCode: statusCode,
    );
  }
}
