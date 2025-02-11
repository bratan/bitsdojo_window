import 'dart:ffi';
import 'package:flutter/painting.dart' as p;
import 'package:ffi/ffi.dart';
import './native_api.dart' as native;
import './gtk.dart';
import 'package:bitsdojo_window_platform_interface/bitsdojo_window_platform_interface.dart';

var isInsideDoWhenWindowReady = false;

bool isValidHandle(int? handle, String operation) {
  if (handle == null) {
    print("Could not $operation - handle is null");
    return false;
  }
  return true;
}

class CachedWindowInfo {
  p.Rect? rect;
}

p.Rect getScreenRectForWindow(int handle) {
  Pointer<Int32> gtkRect = malloc.allocate(sizeOf<Int32>() * 4);
  native.getScreenRect(handle, gtkRect.elementAt(0), gtkRect.elementAt(1),
      gtkRect.elementAt(2), gtkRect.elementAt(3));
  p.Rect result = p.Rect.fromLTWH(gtkRect[0].toDouble(), gtkRect[1].toDouble(),
      gtkRect[2].toDouble(), gtkRect[3].toDouble());
  malloc.free(gtkRect);

  return result;
}

class GtkWindow extends DesktopWindow {
  int? handle;
  p.Size? _minSize;
  p.Size? _maxSize;
  p.Alignment? _alignment;
  // size and position are cached during doWhenWindowReady
  // because the window operations for setting size/position
  // are scheduled and do not run immediately so the results
  // from native getSize/getPosition are not reliable
  // immediatly after the operation

  CachedWindowInfo _cached = CachedWindowInfo();

  GtkWindow() {
    //_alignment = p.Alignment.center;
  }

  @Deprecated("use isVisible instead")
  @override
  bool get visible {
    return isVisible;
  }

  @override
  bool get isVisible {
    //TODO: implement
    return true;
  }

  @override
  p.Rect get rect {
    if (!isValidHandle(handle, "get rectangle")) return p.Rect.zero;

    if (isInsideDoWhenWindowReady == true && _cached.rect != null) {
      return _cached.rect!;
    }

    Pointer<Int32> gtkRect = malloc.allocate(sizeOf<Int32>() * 4);
    native.getPosition(handle!, gtkRect.elementAt(0), gtkRect.elementAt(1));
    native.getSize(handle!, gtkRect.elementAt(2), gtkRect.elementAt(3));
    p.Rect result = p.Rect.fromLTWH(gtkRect[0].toDouble(), gtkRect[1].toDouble(),
        gtkRect[2].toDouble(), gtkRect[3].toDouble());

    malloc.free(gtkRect);
    return result;
  }

  @override
  set rect(p.Rect newRect) {
    if (!isValidHandle(handle, "set rectangle")) return;
    _cached.rect = newRect;
    native.setRect(handle!, newRect.left.toInt(), newRect.top.toInt(),
        newRect.width.toInt(), newRect.height.toInt());
  }

  @override
  p.Size get size {
    if (!isValidHandle(handle, "get size")) return p.Size.zero;

    if (isInsideDoWhenWindowReady == true && _cached.rect != null) {
      return _cached.rect!.size;
    }

    Pointer<Int32> nativeResult = malloc.allocate(sizeOf<Int32>() * 2);
    native.getSize(
        handle!, nativeResult.elementAt(0), nativeResult.elementAt(1));
    p.Size result = p.Size(nativeResult[0].toDouble(), nativeResult[1].toDouble());
    malloc.free(nativeResult);
    final gotSize = getLogicalSize(result);
    return gotSize;
  }

  p.Size get sizeOnScreen {
    if (isInsideDoWhenWindowReady == true && _cached.rect != null) {
      final sizeOnScreen = getSizeOnScreen(_cached.rect!.size);
      return sizeOnScreen;
    }
    final winRect = this.rect;
    return p.Size(winRect.width, winRect.height);
  }

  @override
  double get borderSize {
    return 0.0;
  }

  int get dpi {
    return (96.0 * this.scaleFactor).toInt();
  }

  @override
  double get scaleFactor {
    if (!isValidHandle(handle, "get scaleFactor")) return 1;
    Pointer<Int32> scaleFactorPtr = malloc.allocate(sizeOf<Int32>());
    native.getScaleFactor(handle!, scaleFactorPtr.elementAt(0));
    double result = scaleFactorPtr[0].toDouble();
    malloc.free(scaleFactorPtr);
    return result;
  }

  @override
  double get titleBarHeight {
    // NOTE: This might be difficult to retrieve from gtk
    return 32.0;
  }

  @override
  p.Size get titleBarButtonSize {
    // NOTE: This might be difficult to retrieve from gtk
    p.Size result = p.Size(32, 32);
    return result;
  }

  p.Size getSizeOnScreen(p.Size inSize) {
    double scaleFactor = this.scaleFactor;
    double newWidth = inSize.width * scaleFactor;
    double newHeight = inSize.height * scaleFactor;
    return p.Size(newWidth, newHeight);
  }

  p.Size getLogicalSize(p.Size inSize) {
    double scaleFactor = this.scaleFactor;
    double newWidth = inSize.width / scaleFactor;
    double newHeight = inSize.height / scaleFactor;
    return p.Size(newWidth, newHeight);
  }

  @override
  p.Alignment? get alignment => _alignment;

  /// How the window should be aligned on screen
  @override
  set alignment(p.Alignment? newAlignment) {
    final sizeOnScreen = this.sizeOnScreen;
    _alignment = newAlignment;
    if (_alignment != null) {
      if (!isValidHandle(handle, "set alignment")) return;
      final screenRect = getScreenRectForWindow(handle!);
      this.rect = getRectOnScreen(sizeOnScreen, _alignment!, screenRect);
    }
  }

  @override
  set minSize(p.Size? newSize) {
    if (!isValidHandle(handle, "set minSize")) return;

    _minSize = newSize;
    if (newSize == null) {
      //TODO - add handling for setting minSize to null
      return;
    }
    native.setMinSize(
        handle!, _minSize!.width.toInt(), _minSize!.height.toInt());
  }

  @override
  set maxSize(p.Size? newSize) {
    if (!isValidHandle(handle, "set maxSize")) return;

    _maxSize = newSize;
    if (newSize == null) {
      //TODO - add handling for setting maxSize to null
      return;
    }
    native.setMaxSize(
        handle!, _maxSize!.width.toInt(), _maxSize!.height.toInt());
  }

  @override
  set size(p.Size newSize) {
    if (!isValidHandle(handle, "set size")) return;

    var width = newSize.width;

    if (_minSize != null) {
      if (newSize.width < _minSize!.width) width = _minSize!.width;
    }

    if (_maxSize != null) {
      if (newSize.width > _maxSize!.width) width = _maxSize!.width;
    }

    var height = newSize.height;

    if (_minSize != null) {
      if (newSize.height < _minSize!.height) height = _minSize!.height;
    }

    if (_maxSize != null) {
      if (newSize.height > _maxSize!.height) height = _maxSize!.height;
    }

    p.Size sizeToSet = p.Size(width, height);

    // Save cached rect
    final double left = _cached.rect != null ? _cached.rect!.left : 0;
    final double top = _cached.rect != null ? _cached.rect!.top : 0;
    _cached.rect = p.Rect.fromLTWH(left, top, width, height);

    if (_alignment == null) {
      native.setSize(
          handle!, sizeToSet.width.toInt(), sizeToSet.height.toInt());
      //native.setWindowSize(handle!, sizeToSet);
    } else {
      final sizeOnScreen = getSizeOnScreen((sizeToSet));
      final screenRect = getScreenRectForWindow(handle!);
      this.rect = getRectOnScreen(sizeOnScreen, _alignment!, screenRect);
    }
  }

  @override
  bool get isMaximized {
    if (!isValidHandle(handle, "get isMaximized")) return false;
    return gtkWindowIsMaximized(handle!) == 1;
  }

  @override
  p.Offset get position {
    if (isInsideDoWhenWindowReady == true && _cached.rect != null) {
      return _cached.rect!.topLeft;
    }
    return this.rect.topLeft;
  }

  @override
  set position(p.Offset newPosition) {
    if (!isValidHandle(handle, "set position")) return;
    // Save cached rect
    final double width = _cached.rect != null ? _cached.rect!.width : 0;
    final double height = _cached.rect != null ? _cached.rect!.height : 0;
    _cached.rect = p.Rect.fromLTWH(newPosition.dx, newPosition.dy, width, height);
    native.setPosition(handle!, newPosition.dx.toInt(), newPosition.dy.toInt());
  }

  @override
  void show() {
    if (!isValidHandle(handle, "show")) return;
    p.Offset currentPosition = this.position;
    native.showWindow(handle!);
    this.position = currentPosition;
  }

  @override
  void hide() {
    if (!isValidHandle(handle, "hide")) return;
    native.hideWindow(handle!);
  }

  @Deprecated("use show()/hide() instead")
  @override
  set visible(bool isVisible) {
    if (isVisible) {
      show();
    } else {
      hide();
    }
  }

  @override
  void close() {
    if (!isValidHandle(handle, "close")) return;
    gtkWindowClose(handle!);
  }

  @override
  void maximize() {
    if (!isValidHandle(handle, "maximize")) return;
    native.maximizeWindow(handle!);
  }

  @override
  void minimize() {
    if (!isValidHandle(handle, "minimize")) return;
    native.minimizeWindow(handle!);
  }

  @override
  void restore() {
    if (!isValidHandle(handle, "restore")) return;
    native.unmaximizeWindow(handle!);
  }

  @override
  void maximizeOrRestore() {
    if (!isValidHandle(handle, "maximizeOrRestore")) return;
    if (this.isMaximized) {
      this.restore();
    } else {
      this.maximize();
    }
  }

  @override
  set title(String newTitle) {
    if (!isValidHandle(handle, "set title")) return;
    final nativeString = newTitle.toNativeUtf8();
    native.setWindowTitle(handle!, nativeString);
  }

  @override
  void startDragging() {
    BitsdojoWindowPlatform.instance.dragAppWindow();
  }
}
