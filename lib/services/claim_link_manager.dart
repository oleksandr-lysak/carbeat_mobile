import 'dart:async';

class ClaimLinkPayload {
  final int masterId;
  final String token;

  ClaimLinkPayload({required this.masterId, required this.token});
}

class ClaimLinkManager {
  static final StreamController<ClaimLinkPayload> _controller = StreamController.broadcast();
  static ClaimLinkPayload? _pending;

  static Stream<ClaimLinkPayload> get stream => _controller.stream;

  static void dispatch(ClaimLinkPayload payload) {
    _pending = payload;
    _controller.add(payload);
  }

  static ClaimLinkPayload? consumePending() {
    final payload = _pending;
    _pending = null;
    return payload;
  }
}

