part of 'image_favorites_page.dart';

class ImageFavoritesGroup {
  final String id;
  List<ImageFavorite> imageFavorites;
  final String eid;
  ImageFavoritesGroup(this.id, this.imageFavorites, this.eid);

  // 避免后边收藏图片的时候标题有更新
  String get title {
    return imageFavorites.last.title;
  }

  String get sourceKey {
    return id.split('-')[0];
  }

  String get cid {
    return id.split('-')[1];
  }

  // 最早的那张图片收藏的时间
  DateTime get firstTime {
    return imageFavorites
        .fold(
            imageFavorites[0],
            (prev, current) =>
                prev.time.isBefore(current.time) ? prev : current)
        .time;
  }

  // 是否都有imageKey
  bool get isAllHasImageKey {
    return imageFavorites.every((e) => e.otherInfo["imageKey"] != null);
  }

  // 是否都有封面
  bool get isHasFirstPage {
    return imageFavorites[0].page == 0;
  }
}

class ImageFavoritesItem extends StatefulWidget {
  const ImageFavoritesItem(
      {super.key,
      required this.imageFavoritesGroup,
      required this.selectedImageFavorites,
      required this.addSelected,
      required this.multiSelectMode,
      required this.curImageFavoritesGroup});
  final ImageFavoritesGroup imageFavoritesGroup;
  final Function(ImageFavorite) addSelected;
  final Map<ImageFavorite, bool> selectedImageFavorites;
  final List<ImageFavoritesGroup> curImageFavoritesGroup;
  final bool multiSelectMode;
  @override
  State<ImageFavoritesItem> createState() => ImageFavoritesItemState();
}

class ImageFavoritesItemState extends State<ImageFavoritesItem> {
  bool isImageKeyLoading = false;
  // 刷新 imageKey 失败的场景再刷新一次, 再次失败了就不重试了
  bool hasRefreshImageKeyOnErr = false;
  // 如果 imageKey 失效了, 或者刚从pica导入, 没有就走这个逻辑
  void refreshImageKey() async {
    if (isImageKeyLoading || hasRefreshImageKeyOnErr) return;
    isImageKeyLoading = true;
    ComicSource? comicSource =
        ComicSource.find(widget.imageFavoritesGroup.sourceKey);
    var res = await comicSource!.loadComicPages!(
      widget.imageFavoritesGroup.cid,
      widget.imageFavoritesGroup.eid,
    );
    if (!res.error) {
      List<String> images = res.data;
      // 塞个封面进去
      if (!widget.imageFavoritesGroup.isHasFirstPage) {
        ImageFavorite copyObj = widget.imageFavoritesGroup.imageFavorites[0];
        ImageFavorite temp = ImageFavorite(copyObj.id, '', copyObj.title,
            copyObj.time, copyObj.ep, 0, {'imageKey': images[0]});
        ImageFavoriteManager.add(temp);
      }
      for (var ele in widget.imageFavoritesGroup.imageFavorites) {
        ele.otherInfo["imageKey"] = images[ele.page];
        ImageFavoriteManager.add(ele);
      }
      setState(() {});
    }
    isImageKeyLoading = false;
  }

  @override
  Widget build(BuildContext context) {
    int count = widget.imageFavoritesGroup.imageFavorites.length;
    if (!widget.imageFavoritesGroup.isAllHasImageKey ||
        !widget.imageFavoritesGroup.isHasFirstPage) {
      refreshImageKey();
    }
    String time = DateFormat('yyyy-MM-dd HH:mm:ss')
        .format(widget.imageFavoritesGroup.firstTime);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 0.6,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          if (widget.multiSelectMode) {
            for (var ele in widget.imageFavoritesGroup.imageFavorites) {
              widget.addSelected(ele);
            }
          } else {
            // 单击跳转漫画详情
            App.mainNavigatorKey?.currentContext?.to(() => ComicPage(
                  id: widget.imageFavoritesGroup.id,
                  sourceKey: widget.imageFavoritesGroup.sourceKey,
                ));
          }
        },
        onLongPress: () {
          for (var ele in widget.imageFavoritesGroup.imageFavorites) {
            widget.addSelected(ele);
          }
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 56,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.imageFavoritesGroup.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14.0,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      softWrap: true,
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(count.toString(), style: ts.s12),
                  ),
                ],
              ),
            ).paddingHorizontal(16),
            SizedBox(
              height: 145,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: count,
                itemBuilder: (context, index) {
                  ImageFavorite curImageFavorite =
                      widget.imageFavoritesGroup.imageFavorites[index];
                  ImageProvider image =
                      ImageFavoritesProvider(curImageFavorite);
                  bool isSelected =
                      widget.selectedImageFavorites[curImageFavorite] ?? false;
                  Widget imageWidget = AnimatedImage(
                    image: image,
                    width: 96,
                    height: 128,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.medium,
                    onError: () {
                      refreshImageKey();
                      hasRefreshImageKeyOnErr = true;
                    },
                  );
                  int curPage = curImageFavorite.page;
                  String pageText =
                      curPage == 0 ? 'cover'.tl : (curPage + 1).toString();
                  return InkWell(
                    onDoubleTap: () {
                      // 双击浏览大图
                      App.mainNavigatorKey?.currentContext?.to(
                        () => ImageFavoritesPhotoView(
                          imageFavoritesGroup: widget.imageFavoritesGroup,
                          page: curImageFavorite.page,
                          curImageFavoritesGroup: widget.curImageFavoritesGroup,
                        ),
                      );
                    },
                    onTap: () {
                      // 单击去阅读页面, 跳转到当前点击的page
                      if (widget.multiSelectMode) {
                        widget.addSelected(curImageFavorite);
                      } else {
                        App.mainNavigatorKey?.currentContext?.to(
                          () => ReaderWithLoading(
                            id: widget.imageFavoritesGroup.id,
                            sourceKey: widget.imageFavoritesGroup.sourceKey,
                          ),
                        );
                      }
                    },
                    onLongPress: () {
                      widget.addSelected(curImageFavorite);
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                        width: 98,
                        height: 128,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: isSelected
                              ? Theme.of(context).colorScheme.secondaryContainer
                              : null,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(
                          children: [
                            Container(
                                height: 128,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  color: Theme.of(context)
                                      .colorScheme
                                      .secondaryContainer,
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: imageWidget),
                            Text(pageText, style: ts.s12)
                          ],
                        )),
                  );
                },
              ),
            ).paddingHorizontal(8),
            Row(
              children: [
                Text(
                  "最早收藏时间: $time | ${widget.imageFavoritesGroup.sourceKey}",
                  textAlign: TextAlign.left,
                  style: const TextStyle(
                    fontSize: 12.0,
                  ),
                )
              ],
            ).paddingHorizontal(16).paddingBottom(8),
          ],
        ),
      ),
    );
  }
}
