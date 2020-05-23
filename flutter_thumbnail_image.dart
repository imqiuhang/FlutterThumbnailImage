import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

/*
* feature
*   1. 自动获取真实的图片大小，自动拼接裁剪参数的图片，
*   2. TODO 提供图片磁盘缓存 即将通过图片纹理支持对接native SDWebImage
*   3. 提供 placeHolder
*
* ** 全自适应的图片(布局上不指定宽高比例，也不指定宽高)的不会裁剪
* ** 因为依靠自适应撑开的布局在加载图片之前 宽和高必定有一个无法确定！
*
* usage
*   appendClipParameter : 是否自动拼接ClipSize 默认true
*                  如果传入width和height 则使用width和height
*                  如果未传入则在布局结束后获取当前Widget的size
*                  * ClipSize通过bridge调用native的OSS或NOS获取拼接后的URL *
* 
* placeholder
*   如果传入placeHolder widget 则优先使用
*   否则使用placeHolderIcon以及placeHolderColor生成如果传入placeHolder
* 
* cache TODO
*   * 使用 CachedNetworkImage 或者 对接native cache SDK *
* 
* 
* */

typedef FlutterThumbnailClipHandler = Future<String> Function(
    String image, int width, int height);

class FlutterThumbnailClipHandlerRegister {
  /* 注册裁剪的处理方
  *  image 原始图的URL
  * width 最终展示的宽度(dp) 最好根据屏幕scale转成px来处理
  * height 同上
  * */
  static registerClipHandler(FlutterThumbnailClipHandler clipHandler) {
    _clipHandler = clipHandler;
  }

  static FlutterThumbnailClipHandler _clipHandler;

  static get clipHandler => _clipHandler;
}

class FlutterThumbnailImage extends StatefulWidget {
  FlutterThumbnailImage(this.image,
      {Key key,
      this.appendClipParameter = true,
      this.fit = BoxFit.cover,
      this.placeHolderImage,
      this.placeHolderColor,
      this.placeHolder,
      this.width,
      this.height})
      : super(key: key);

  final String image;
  final bool appendClipParameter; // 是否拼接裁剪参数 default is true
  final String placeHolderImage; // 本地占位图
  final Color placeHolderColor; // 占位色
  final Widget placeHolder; // 自定义占位widget
  final BoxFit fit;
  final double width;
  final double height;

  @override
  _FlutterThumbnailImageState createState() => _FlutterThumbnailImageState();
}

class _FlutterThumbnailImageState extends State<FlutterThumbnailImage> {
  //
  bool _didPostFrame = false;

  String _thumbnailImage;
  bool _didDoFetchClipSizeOperation = false; // 是否已经进行过fetch操作
  bool _didFetchClipSizeError = false; // 是否fetch失败

  @override
  void initState() {
    super.initState();
    _resetAll();
    bool hasSize = !_checkSizeIsZero(widget.width, widget.height);
    if (hasSize) {
      _fetchClipSizeImageUrlIfNeed();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _didPostFrame = true;
        _fetchClipSizeImageUrlIfNeed();
      });
    }
  }

  @override
  void didUpdateWidget(FlutterThumbnailImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // @discuss TODO 如果size变化了需不需要重新裁剪？有没有这种需求？
    // 无脑刷的话 下拉刷新会重刷 感受不太好
    // 后续如果要加要存下之前计算的实际大小 和 现在的大小做对比
    if (oldWidget.image != widget.image) {
      _resetAll();
      if (mounted) {
        setState(() {});
      }
      _fetchClipSizeImageUrlIfNeed();
    }
  }

  _resetAll() {
    _thumbnailImage = null;
    _didDoFetchClipSizeOperation = false;
    _didFetchClipSizeError = false;
  }

  _fetchClipSizeImageUrlIfNeed() async {
    //
    if (_checkStringIsEmpty(widget.image)) {
      return;
    }

    if (!widget.appendClipParameter) {
      return;
    }

    if (_didDoFetchClipSizeOperation) {
      return;
    }

    double width = widget.width;
    double height = widget.height;

    if (_checkSizeIsZero(width, height)) {
      if (!_didPostFrame) {
        //不需要置为error, _didPostFrame还有机会
        return;
      }

      try {
        Size size = context?.findRenderObject()?.paintBounds?.size;
        if (size != null) {
          width = size.width;
          height = size.height;
        }
      } catch (e) {}
    }

    // 不管是成功失败，都算作已经获取过了
    _didDoFetchClipSizeOperation = true;

    // 如果获取到widget的宽高了 那么就去native区裁剪
    if (!_checkSizeIsZero(width, height)) {
      assert(FlutterThumbnailClipHandlerRegister.clipHandler != null,
          "必须通过FlutterThumbnailClipHandlerRegister注册clipHandler");
      
      Map result = await FlutterThumbnailClipHandlerRegister.clipHandler(
          widget.image, width.toInt(), height.toInt(), null);

      _thumbnailImage =
          _safeTypeMatchedValueFromMap<String>(result, "imageUrl");
    }

    if (_checkStringIsEmpty(_thumbnailImage)) {
      // 获取参数失败
      _didFetchClipSizeError = true;
    }

    if (mounted) {
      setState(() {});
    }
  }

  bool _checkSizeIsZero(double width, double height) {
    // 加上0.0的判断是为了 全自适应的图片不去做图片裁剪
    // 因为自适应的图片宽高必定有一个是0.0
    if (width == null ||
        height == null ||
        width == 0.0 ||
        height == 0.0 ||
        width.isNaN ||
        height.isNaN) {
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    String imageURL;
    // 不拼接ClipSize 或者 获取ClipSize失败的时候直接显示原图
    // 如果还在获取中则只显示placeholder
    if (!widget.appendClipParameter || _didFetchClipSizeError) {
      imageURL = widget.image;
    } else {
      imageURL = _thumbnailImage;
    }

    Widget placeHolder = widget.placeHolder;

    if (placeHolder == null) {
      bool hasPlaceHolderIcon = _checkStringIsNotEmpty(widget.placeHolderImage);
      placeHolder = Container(
        width: widget.width,
        height: widget.height,
        color: widget.placeHolderColor,
        child: hasPlaceHolderIcon
            ? Center(
                child: Image.asset(widget.placeHolderImage),
              )
            : null,
      );
    }

    Widget item = placeHolder;

    if (imageURL != null) {
      item = FTIPlaceHolderImage(
          image: imageURL,
          fit: widget.fit,
          width: widget.width,
          height: widget.height,
          placeholder: placeHolder);
    }

    return item ?? Container();
  }
}

////////////////// PlaceHolderImage //////////////////////////////////
class FTIPlaceHolderImage extends StatelessWidget {
  FTIPlaceHolderImage(
      {Key key,
      @required this.placeholder,
      @required String image,
      this.fit,
      this.width,
      this.height})
      : imageProvider = NetworkImage(image),
        super(key: key);

  //
  final Widget placeholder;
  final ImageProvider imageProvider;
  final BoxFit fit;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return _buildImage(
      imageProvider: imageProvider,
      frameBuilder: (BuildContext context, Widget child, int frame,
          bool wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded) return child;
        bool isTargetLoaded = (frame != null);
        return isTargetLoaded ? child : placeholder;
      },
    );
  }

  Widget _buildImage({
    @required ImageProvider imageProvider,
    ImageFrameBuilder frameBuilder,
  }) {
    assert(imageProvider != null);
    return Image(
      image: imageProvider,
      frameBuilder: frameBuilder,
      fit: fit,
      width: width,
      height: height,
    );
  }
}

/// Utility
T _safeTypeMatchedValueFromMap<T>(Map map, dynamic key, {T defaultValue}) {
  if (map == null || key == null) {
    return defaultValue;
  }

  dynamic value = map[key];
  if (value == null || !(value is T)) {
    return defaultValue;
  }
  return value;
}

//(A?.B?.C?.string ?? "").isEmpty
bool _checkStringIsEmpty(String string) =>
    (string == null) ? true : string.isEmpty;

//(A?.B?.C?.string ?? "").isNotEmpty
bool _checkStringIsNotEmpty(String string) => !_checkStringIsEmpty(string);
