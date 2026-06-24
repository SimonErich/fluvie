import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:web_server_studio/render/spec_builder.dart';
import 'package:web_server_studio/services/server_render_service.dart';
import 'package:web_server_studio/submit/submit_state.dart';

/// The render server URL, baked at build time so the hosted demo points at its
/// API; falls back to a local server for development.
const String _defaultServerUrl = String.fromEnvironment(
  'FLUVIE_API_URL',
  defaultValue: 'http://localhost:8080',
);

/// Drives the submit screen: edits the promo and renders it on the server.
class SubmitViewModel extends Notifier<SubmitState> {
  @override
  SubmitState build() => const SubmitState(
    headline: 'Kitten Mitten',
    tagline: 'Cozy paws, happy days',
    accentHex: '#FF8FB1',
    serverUrl: _defaultServerUrl,
    apiToken: '',
  );

  /// Sets the headline.
  void setHeadline(String value) => state = state.copyWith(headline: value);

  /// Sets the tagline.
  void setTagline(String value) => state = state.copyWith(tagline: value);

  /// Sets the accent hex.
  void setAccent(String hex) => state = state.copyWith(accentHex: hex);

  /// Sets the server URL.
  void setServerUrl(String value) => state = state.copyWith(serverUrl: value);

  /// Sets the API token.
  void setApiToken(String value) => state = state.copyWith(apiToken: value);

  /// Validates the form and renders the promo on the server.
  Future<void> submit() async {
    if (state.isSubmitting) return;
    final baseUrl = _validBaseUrl(state.serverUrl);
    if (baseUrl == null) {
      state = state.copyWith(
        status: SubmitStatus.failed,
        error: 'Enter a valid http(s) server URL.',
      );
      return;
    }
    state = state.copyWith(
      status: SubmitStatus.submitting,
      progress: 0,
      clearError: true,
      clearUrl: true,
    );
    final token = state.apiToken.trim();
    try {
      final url = await ref
          .read(serverRenderServiceProvider)
          .render(
            baseUrl: baseUrl,
            apiToken: token.isEmpty ? null : token,
            spec: kittenPromoSpec(
              headline: state.headline,
              tagline: state.tagline,
              accentHex: state.accentHex,
            ),
            onProgress: (progress) => state = state.copyWith(progress: progress),
          );
      state = state.copyWith(
        status: SubmitStatus.done,
        progress: 1,
        downloadUrl: url,
      );
    } on ServerRenderException catch (error) {
      state = state.copyWith(status: SubmitStatus.failed, error: error.message);
    } on Object catch (error) {
      state = state.copyWith(status: SubmitStatus.failed, error: '$error');
    }
  }

  /// Parses [raw] and returns it only when it is an http(s) URL with a host.
  static Uri? _validBaseUrl(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null || uri.host.isEmpty) return null;
    if (!uri.isScheme('http') && !uri.isScheme('https')) return null;
    return uri;
  }
}

/// The submit view-model provider.
final NotifierProvider<SubmitViewModel, SubmitState> submitViewModelProvider =
    NotifierProvider<SubmitViewModel, SubmitState>(SubmitViewModel.new);
