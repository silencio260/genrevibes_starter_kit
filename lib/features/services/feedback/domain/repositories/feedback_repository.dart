import 'package:dartz/dartz.dart';
import 'package:starter_kit/core/error/failure.dart';

abstract class FeedbackRepository {
  /// Submit user feedback text
  Future<Either<Failure, void>> submitFeedback(String text, {String? email});
}
