# FlutterThumbnailImage

#### 等有时间做完 通过纹理将图片缓存对接到native的缓存框架(例如iOS的SDWebImage)就会打包到pub里

###### flutter image,自动裁剪参数拼接、自定义placeholder支持、图片纹理对接native缓存


#### 有什么用？
1. 自动拼接KLSize的图片(可以不传width和height)
2. TODO 提供图片磁盘缓存(后续已使用的地方不需要改接口)
3. 提供 placeHolder(图，背景色或者自定义)
#### 为什么用
1. 以feed流中一个30*30dp(3倍屏90*90px)如此小的头像，原图570K，使用90*90裁剪以后压缩到4K，加载时间减少明显，feed流的大图片效果同理。
2. 方便后期统一做缓存处理


#### 参数
###### 必选
``` dart
image String 原图URL
```

###### 可选

``` dart
appendKLSize bool 是否拼接KLSize参数，默认true
placeHolderImage String 居中适应的 占位图
placeHolderColor Color 整个区域的占位背景色
placeHolder Widget 完全自定义的占位widget 如提供则忽略上面两个
fit BoxFit image的fit
width / height double image的size 居中适应的 占位图,如果传了，拼接参数会直接使用这个尺寸，如果不传，则会在渲染之后拿到当前widget的render object取size后再去做拼接
```
##### Usage 
``` dart
KLImage.largePlaceholderStyle(...)  //考拉(大)占位图 ，默认灰色底占位 ，默认BoxFit.cover 适合feed流的大图封面
KLImage.grayColorStyle(...)  //默认灰色底占位，无占位图，默认BoxFit.cover，适合头像，商品图等小图
```

##### 如何工作？

![flow](https://github.com/imqiuhang/FlutterThumbnailImage/blob/master/1584964057796-deefb231-930c-4f8b-8ab8-a38b0427875e.jpeg)
