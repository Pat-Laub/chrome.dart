// http://developer.chrome.com/trunk/apps/runtime.html
library chrome.runtime;

import 'dart:async';

import 'package:js/js.dart' as js;

import 'common.dart';
import 'files.dart';
import 'tabs.dart';

/// Accessor for the `chrome.runtime` namespace.
final Runtime runtime = new Runtime._();

/**
 * Created from [Runtime].lastError checks.
 */
class RuntimeError {
  /**
   * Details about the error which occurred.
   */
  final String message;
  RuntimeError(this.message);

  String toString() => 'RuntimeError: $message';
}

class Runtime {

  Runtime._();

  dynamic get _runtime => chromeProxy.runtime;

  /**
   * This will be defined during an API method callback if there was an error.
   */
  RuntimeError get lastError {
    return js.scoped(() {
      var lastError = _runtime['lastError'];

      if (lastError == null) {
        return null;
      } else {
        return new RuntimeError(lastError.message);
      }
    });
  }

  /**
   * The ID of the extension/app.
   */
  String get id {
    return js.scoped(() {
      return _runtime.id;
    });
  }

  /// Methods

  /**
   * Retrieves the js.Proxy window object for the background page
   * running inside the current extension.
   *
   * If the background page is an event page,
   * the system will ensure it is loaded before calling the callback.
   * If there is no background page, an error is set.
   */
  Future<js.Proxy> getBackgroundPage() {
    ChromeCompleter completer = new ChromeCompleter.oneArg((window) {
      // XXX: This is a hack, remove or dont send the entire window object
      // as a js.Proxy to the completer.
      js.retain(window);
      return window;
    });

    js.scoped(() {
      _runtime.getBackgroundPage(completer.callback);
    });

    return completer.future;
  }

  /**
   * Returns details about the app or extension from the manifest.
   *
   * The [Map] returned is a de-serialization of the full manifest file.
   */
  Map getManifest() {
    return js.scoped(() {
      return convertJsonResponse(_runtime.getManifest());
    });
  }

  /**
   * Converts a relative path within an app/extension
   * install directory to a fully-qualified URL.
   *
   * A [path] to a resource within an app/extension
   * expressed relative to its install directory.
   */
  String getURL(String path) {
    return js.scoped(() {
      return _runtime.getURL(path);
    });
  }

  /**
   * Reloads the app or extension.
   */
  void reload() {
    js.scoped(() {
      _runtime.reload();
    });
  }

  /**
   * Requests an update check for this app/extension.
   */
  Future<UpdateDetails> requestUpdateCheck() {
    var completer = new ChromeCompleter.twoArgs((status, details) {
      switch (status) {
        case 'no_update':
          return UpdateDetails.NO_UPDATE;
        case 'throttled':
          return UpdateDetails.THROTTLED;
        case 'update_available':
          return new UpdateDetails.available(details.version);
        default:
          throw 'unknown status: $status';
      }
    });

    js.scoped(() {
      _runtime.requestUpdateCheck(completer.callback);
    });

    return completer.future;
  }

  /**
   * Sends a single message to onMessage event listeners within the extension
   * (or another extension/app). Similar to chrome.runtime.connect, but only
   * sends a single message with an optional response. The onMessage event is
   * fired in each extension page of the extension. Note that extensions cannot
   * send messages to content scripts using this method. To send messages to
   * content scripts, use tabs.sendMessage.
   *
   * Returns the JSON response object sent by the handler of the message.
   */
  Future<dynamic> sendMessage(dynamic message) {
    var completer = new ChromeCompleter.oneArg(convertJsonResponse);
    js.scoped(() {
      _runtime.sendMessage(jsifyMessage(message), completer.callback);
    });
    return completer.future;
  }

  /**
   * Returns a DirectoryEntry for the package directory.
   */
  Future<DirectoryEntry> getPackageDirectoryEntry() {
    ChromeCompleter<DirectoryEntry> completer =
        new ChromeCompleter.oneArg(Entry.createFrom);
    _runtime.getPackageDirectoryEntry(completer.callback);
    return completer.future;
  }

  /// Returns information about the current platform.
  Future<PlatformInfo> getPlatformInfo() {
    final completer = new ChromeCompleter.oneArg((platformInfo) =>
        new PlatformInfo._(platformInfo));
    _runtime.getPlatformInfo(completer.callback);
    return completer.future;
  }

  /// Events

  final ChromeStreamController _onStartup =
      new ChromeStreamController.zeroArgs(
          () => chromeProxy.runtime.onStartup,
          () => null);

  /**
   * Fired when the browser first starts up.
   */
  Stream get onStartup => _onStartup.stream;

  final ChromeStreamController<InstalledEvent> _onInstalled =
      new ChromeStreamController<InstalledEvent>.oneArg(
          () => chromeProxy.runtime.onInstalled,
          (details) => new InstalledEvent._(
              details.reason, details['previousVersion']));

  /**
   * Fired when the extension is first installed,
   * when the extension is updated to a new version,
   * and when Chrome is updated to a new version.
   */
  Stream<InstalledEvent> get onInstalled => _onInstalled.stream;

  final ChromeStreamController _onSuspend =
      new ChromeStreamController.zeroArgs(
          () => chromeProxy.runtime.onSuspend,
          () => null);

  /**
   * Sent to the event page just before it is unloaded.
   *
   * This gives the extension opportunity to do some clean up.
   * Note that since the page is unloading, any asynchronous
   * operations started while handling this event are not guaranteed
   * to complete. If more activity for the event page occurs
   * before it gets unloaded the onSuspendCanceled event will be
   * sent and the page won't be unloaded.
   */
  Stream get onSuspend => _onSuspend.stream;

  final ChromeStreamController _onSuspendCanceled =
      new ChromeStreamController.zeroArgs(
          () => chromeProxy.runtime.onSuspendCanceled,
          () => null);

  /**
   * Sent after onSuspend() to indicate that the app won't be unloaded after
   * all.
   */
  Stream get onSuspendCanceled => _onSuspendCanceled.stream;

  final ChromeStreamController<String> _onUpdateAvailable =
      new ChromeStreamController<String>.oneArg(
          () => chromeProxy.runtime.onUpdateAvailable,
          (details) => details.version);

  /**
   * Fired when an update is available.
   *
   * Isn't installed immediately because the app is currently running.
   * If you do nothing, the update will be installed the next time
   * the background page gets unloaded, if you want it to be installed
   * sooner you can explicitly call chrome.runtime.reload().
   *
   * Message is the version number of the available update.
   */
  Stream<String> get onUpdateAvailable => _onUpdateAvailable.stream;

  ChromeStreamController<MessageEvent> _onMessage =
      new ChromeStreamController<MessageEvent>.threeArgs(
          () => chromeProxy.runtime.onMessage,
          (message, sender, sendResponse) => new MessageEvent(
                convertJsonResponse(message),
                new MessageSender(sender),
                sendResponse),
          true);

  /**
   * Fired when a message is sent from either an extension process or a content
   * script.
   */
  Stream<MessageEvent> get onMessage => _onMessage.stream;
}

class MessageSender {
  final String id;
  final String url;
  final Tab tab;

  MessageSender._(this.id, this.url, this.tab);

  MessageSender(sender) : this._(
      sender.id,
      sender['url'],
      sender['tab'] != null ? new Tab(sender.tab) : null);
}

class UpdateDetails {
  final String status;
  final int version;

  const UpdateDetails._(this.status, this.version);

  const UpdateDetails.available(version) : this._('update_available', version);

  static const UpdateDetails NO_UPDATE =
      const UpdateDetails._('no_update', null);

  static const UpdateDetails THROTTLED =
      const UpdateDetails._('throttled', null);

  @override
  bool operator ==(UpdateDetails other) =>
      status == other.status && version == other.version;

  @override
  int get hashCode => status.hashCode + (version != null ? version : 0);
}


class InstalledEvent {
  /// an enumerated string of 'install', 'update', 'chrome_update'
  final String reason;
  /**
   * indicates the previous version  of the extension, which has just been
   * updated. This is present only if [reason] is 'update'.
   */
  final String previousVersion;

  InstalledEvent._(this.reason, this.previousVersion);
}

class MessageEvent {
  final dynamic message;
  final MessageSender sender;
  var _sendResponse;

  MessageEvent(this.message, this.sender, this._sendResponse) {
    js.retain(_sendResponse);
  }

  /**
   * Function to call (at most once) when you have a response. The argument
   * should be any JSON-ifiable object. If you have more than one onMessage
   * listener in the same document, then only one may send a response.
   */
  void sendResponse([dynamic message]) {
    if (!responseSent) {
      js.scoped(() {
        _sendResponse.call(jsifyMessage(message));
      });
      js.release(_sendResponse);
      _sendResponse = null;
    } else {
      throw 'Response already sent.';
    }
  }

  bool get responseSent => _sendResponse == null;
}

/// Information about the current platform.
class PlatformInfo {
  /// The operating system chrome is running on.
  ///
  /// One of "mac", "win", "android", "cros", "linux", or "openbsd".
  final String os;

  /// The machine's processor architecture.
  ///
  /// One of "arm", "x86-32", or "x86-64".
  final String arch;

  /// The native client architecture. This may be different from arch on some
  /// platforms.
  ///
  /// One of "arm", "x86-32", or "x86-64".
  final String nacl_arch;

  PlatformInfo._(proxy)
      : os = proxy.os
      , arch = proxy.arch
      , nacl_arch = proxy.nacl_arch;
}
