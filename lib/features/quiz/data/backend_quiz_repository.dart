import 'dart:async';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../domain/quiz_catalog.dart';
import '../domain/quiz_definition.dart';
import '../domain/quiz_exceptions.dart';
import '../domain/quiz_repository.dart';
import '../domain/quiz_rules.dart';
import '../domain/quiz_validation.dart';
import 'dto/daily_quiz_response.dart';
import 'dto/quick_play_response.dart';
import 'dto/quiz_catalog_response.dart';

final class BackendQuizRepository implements QuizRepository {
  BackendQuizRepository({
    required ApiClient apiClient,
    Duration requestTimeout = const Duration(seconds: 20),
  }) : _apiClient = apiClient,
       _requestTimeout = requestTimeout {
    if (requestTimeout <= Duration.zero) {
      throw ArgumentError.value(
        requestTimeout,
        'requestTimeout',
        'Must be positive',
      );
    }
  }
  final ApiClient _apiClient;
  final Duration _requestTimeout;

  @override
  Future<QuizCatalog> getCatalog() => _request(
    () => _apiClient.getJson('/v1/quizzes/catalog'),
    (json) => QuizCatalogResponse.fromJson(json).toDomain(),
  );

  @override
  Future<QuickPlayQuizDefinition> createQuickPlay({
    required int questionCount,
    String? collectionId,
  }) async {
    _validateCount(questionCount);
    if (collectionId != null) {
      try {
        requireId(collectionId);
      } on InvalidQuizDefinitionException catch (error) {
        throw QuizException(
          QuizFailureKind.invalidSelection,
          'Choose an available collection.',
          cause: error,
        );
      }
    }
    return _request(
      () => _apiClient.postJson(
        '/v1/quizzes/quick-play',
        body: {'questionCount': questionCount, 'collectionId': ?collectionId},
      ),
      (json) {
        final quiz = QuickPlayResponse.fromJson(json).toDomain();
        requireQuiz(
          quiz.questionCount == questionCount,
          'Response count differs from request',
        );
        requireQuiz(
          quiz.selection.collectionId == collectionId,
          'Response selection differs from request',
        );
        return quiz;
      },
    );
  }

  @override
  Future<DailyQuizDefinition> getDaily({
    required String timezone,
    required int questionCount,
  }) async {
    _validateCount(questionCount);
    if (timezone.trim().isEmpty) {
      throw QuizException(
        QuizFailureKind.invalidTimezone,
        'Could not determine your timezone.',
        cause: ArgumentError('Blank timezone'),
      );
    }
    return _request(
      () => _apiClient.getJson(
        '/v1/quizzes/daily',
        queryParameters: {
          'timezone': timezone,
          'questionCount': questionCount.toString(),
        },
      ),
      (json) {
        final quiz = DailyQuizResponse.fromJson(json).toDomain();
        requireQuiz(
          quiz.questionCount == questionCount,
          'Response count differs from request',
        );
        return quiz;
      },
    );
  }

  void _validateCount(int count) {
    if (!QuizRules.questionCounts.contains(count)) {
      throw QuizException(
        QuizFailureKind.invalidSelection,
        'Choose an available question count.',
        cause: ArgumentError.value(count, 'questionCount'),
      );
    }
  }

  Future<T> _request<T>(
    Future<Map<String, Object?>> Function() send,
    T Function(Map<String, Object?>) map,
  ) async {
    try {
      // Bounds waiting only. Do not close the shared client: transport can finish
      // later, but its completion cannot change this operation's timeout result.
      final json = await send().timeout(_requestTimeout);
      return map(json);
    } on QuizException {
      rethrow;
    } on ApiException catch (error) {
      final kind = switch ((error.kind, error.statusCode, error.code)) {
        (ApiExceptionKind.invalidJson, _, _) => QuizFailureKind.invalidContent,
        (ApiExceptionKind.http, 400, 'insufficient_quiz_questions') ||
        (
          ApiExceptionKind.http,
          404,
          'quiz_collection_not_found',
        ) => QuizFailureKind.invalidSelection,
        (ApiExceptionKind.http, 400, 'invalid_timezone') =>
          QuizFailureKind.invalidTimezone,
        (ApiExceptionKind.http, 503, 'quiz_unavailable') =>
          QuizFailureKind.unavailable,
        _ => QuizFailureKind.request,
      };
      throw QuizException(kind, _message(kind), cause: error);
    } on FormatException catch (error) {
      throw QuizException(
        QuizFailureKind.invalidContent,
        _message(QuizFailureKind.invalidContent),
        cause: error,
      );
    } on InvalidQuizDefinitionException catch (error) {
      throw QuizException(
        QuizFailureKind.invalidContent,
        _message(QuizFailureKind.invalidContent),
        cause: error,
      );
    } catch (error) {
      throw QuizException(
        QuizFailureKind.request,
        _message(QuizFailureKind.request),
        cause: error,
      );
    }
  }

  String _message(QuizFailureKind kind) => switch (kind) {
    QuizFailureKind.invalidContent =>
      'Quiz content could not be read. Please try again.',
    QuizFailureKind.invalidSelection =>
      'This selection is no longer available. Refresh and choose again.',
    QuizFailureKind.invalidTimezone =>
      'Could not resolve your timezone. Please try again.',
    QuizFailureKind.unavailable =>
      'Quiz content is unavailable right now. Please try again.',
    _ => 'Could not load the quiz. Please try again.',
  };
}
