import 'package:genrevibes_auth/genrevibes_auth.dart';
import 'package:test/test.dart';

void main() {
  group('AuthUser', () {
    test('copies provider ids so an account cannot mutate after construction',
        () {
      final ids = <String>{'password'};
      final user = AuthUser(id: 'u1', isAnonymous: false, providerIds: ids);

      expect(() => user.providerIds.add('google.com'), throwsUnsupportedError);
      expect(user.hasProvider('password'), isTrue);
      expect(user.hasProvider('google.com'), isFalse);
    });

    test('an anonymous user carries no email', () {
      final user = AuthUser(id: 'u1', isAnonymous: true);

      expect(user.email, isNull);
      expect(user.isEmailVerified, isFalse);
    });
  });

  group('AuthCredentialRequest', () {
    test('each request reports the method it represents', () {
      expect(const AnonymousAuthRequest().method, 'anonymous');
      expect(const GoogleAuthRequest().method, 'google.com');
      expect(
        const AppleAuthRequest(identityToken: 't').method,
        'apple.com',
      );
      expect(
        const EmailPasswordAuthRequest(email: 'a@b.c', password: 'x').method,
        'password',
      );
    });

    test('a Google request without tokens is detectable before it is sent', () {
      expect(const GoogleAuthRequest().hasToken, isFalse);
      expect(const GoogleAuthRequest(idToken: 'abc').hasToken, isTrue);
      expect(const GoogleAuthRequest(idToken: '').hasToken, isFalse);
    });

    test('email and password registration is a flag, not a separate call', () {
      const request = EmailPasswordAuthRequest(
        email: 'a@b.c',
        password: 'x',
        createIfMissing: true,
      );

      expect(request.createIfMissing, isTrue);
    });

    test('the sealed hierarchy covers every method exhaustively', () {
      String describe(AuthCredentialRequest request) => switch (request) {
            AnonymousAuthRequest() => 'guest',
            GoogleAuthRequest() => 'google',
            AppleAuthRequest() => 'apple',
            EmailPasswordAuthRequest() => 'password',
          };

      expect(describe(const AnonymousAuthRequest()), 'guest');
      expect(describe(const AppleAuthRequest(identityToken: 't')), 'apple');
    });
  });

  group('AuthCapabilities', () {
    test('an adapter declares what it cannot do', () {
      const capabilities = AuthCapabilities(
        anonymous: true,
        emailPassword: true,
        federated: true,
        linking: true,
        passwordReset: true,
        accountDeletion: false,
      );

      expect(capabilities.accountDeletion, isFalse);
      expect(capabilities.linking, isTrue);
    });
  });
}
