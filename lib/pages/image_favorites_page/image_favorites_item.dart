part of 'image_favorites_page.dart';

class _ImageFavoritesItem extends StatefulWidget {
  const _ImageFavoritesItem({
    required this.imageFavoritesComic,
    required this.selectedImageFavorites,
    required this.addSelected,
    required this.multiSelectMode,
    required this.finalImageFavoritesComicList,
    required this.isRefreshComicList,
    required this.setRefreshComicList,
    this.imageFavoritesCompute,
  });

  final ImageFavoritesComic imageFavoritesComic;
  final Function(ImageFavorite) addSelected;
  final Map<ImageFavorite, bool> selectedImageFavorites;
  final List<ImageFavoritesComic> finalImageFavoritesComicList;
  final bool multiSelectMode;
  final List<_LoadingImageFavoritesComicRes> isRefreshComicList;
  final Function(_LoadingImageFavoritesComicRes) setRefreshComicList;
  final ImageFavoritesCompute? imageFavoritesCompute;

  @override
  State<_ImageFavoritesItem> createState() => _ImageFavoritesItemState();
}

class _ImageFavoritesItemState extends State<_ImageFavoritesItem> {
  bool isImageKeyLoading = false;

  // 刷新 imageKey 失败的场景再刷新一次, 再次失败了就不重试了
  bool hasRefreshImageKeyOnErr = false;
  late _LoadingImageFavoritesComicRes loadingImageFavoritesComicRes;

  // 如果刚从pica导入(没有imageKey) 或者 imageKey 失效了, 刷新一下
  void refreshImageKey(ImageFavoritesEp imageFavoritesEp) async {
    try {
      if (isImageKeyLoading ||
          hasRefreshImageKeyOnErr ||
          loadingImageFavoritesComicRes.isLoaded) {
        return;
      }
      loadingImageFavoritesComicRes.isLoaded = true;
      widget.setRefreshComicList(loadingImageFavoritesComicRes);
      isImageKeyLoading = true;
      ComicSource? comicSource =
          ComicSource.find(widget.imageFavoritesComic.sourceKey);
      // 拿一下漫画信息和对应章节的图片
      var resArr = await Future.wait([
        comicSource!.loadComicPages!(
          widget.imageFavoritesComic.id,
          imageFavoritesEp.eid,
        ),
        comicSource.loadComicInfo!(
          widget.imageFavoritesComic.id,
        )
      ]);
      Res<List<String>> comicPagesRes = resArr[0] as Res<List<String>>;
      Res<ComicDetails> comicInfoRes = resArr[1] as Res<ComicDetails>;
      if (comicInfoRes.errorMessage?.contains("404") ?? false) {
        loadingImageFavoritesComicRes.isInvalid = true;
        widget.setRefreshComicList(loadingImageFavoritesComicRes);
        if (mounted) {
          setState(() {});
        }
        return;
      }
      if (!comicInfoRes.error) {
        // 刷新一下值, 保存最新的
        widget.imageFavoritesComic.author =
            comicInfoRes.data.findAuthor() ?? "";
        widget.imageFavoritesComic.subTitle = comicInfoRes.data.subTitle ?? '';
        widget.imageFavoritesComic.tags = comicInfoRes.data.plainTags;
        widget.imageFavoritesComic.translatedTags = widget
            .imageFavoritesComic.tags
            .map((e) => e.translateTagsToCN)
            .toList();
        imageFavoritesEp.epName = comicInfoRes.data.chapters?.values
                .elementAtOrNull(imageFavoritesEp.ep - 1) ??
            "";
      } else {
        return;
      }
      if (comicPagesRes.error) {
        // 能加载漫画信息, 说明只是章节对不太上, 刷新一下章节
        var chapters = comicInfoRes.data.chapters;
        // 兜底一下, 如果不是从pica导入的空字符串, 说明是调用接口更新过章节的, 比如jm, 避免丢失最初正确的eid
        // 拷贝等多章节可能会更新章节顺序, 后续如果碰到这种情况多的话, 就在右上角出一个功能批量刷新一下
        if (imageFavoritesEp.eid != "") {
          return;
        }
        var finalEid = chapters?.keys.elementAt(imageFavoritesEp.ep - 1) ?? '0';
        var resArr = await Future.wait([
          comicSource.loadComicPages!(
            widget.imageFavoritesComic.id,
            finalEid,
          )
        ]);
        comicPagesRes = resArr[0];
        if (comicPagesRes.error) {
          return;
        } else {
          imageFavoritesEp.eid = finalEid;
        }
      }
      List<String> images = comicPagesRes.data;
      widget.imageFavoritesComic.maxPage = images.length;
      imageFavoritesEp.maxPage = images.length;
      // 塞一个封面进去
      if (!imageFavoritesEp.isHasFirstPage) {
        ImageFavorite copy = imageFavoritesEp.imageFavorites[0].copyWith(
          page: firstPage,
          isAutoFavorite: true,
        );
        imageFavoritesEp.imageFavorites.insert(0, copy);
      }
      // 统一刷一下最新的imageKey
      for (var ele in imageFavoritesEp.imageFavorites) {
        ele.imageKey = images[ele.page - 1];
      }
      ImageFavoriteManager().addOrUpdateOrDelete(widget.imageFavoritesComic);
      if (mounted) {
        setState(() {});
      }
      isImageKeyLoading = false;
    } catch (e, stackTrace) {
      Log.error("Unhandled Exception", e.toString(), stackTrace);
    }
  }

  void goComicInfo(ImageFavoritesComic comic) {
    App.mainNavigatorKey?.currentContext?.to(() => ComicPage(
          id: comic.id,
          sourceKey: comic.sourceKey,
        ));
  }

  void goReaderPage(ImageFavoritesComic comic, int ep, int page) {
    App.mainNavigatorKey?.currentContext?.to(
      () => ReaderWithLoading(
        id: comic.id,
        sourceKey: comic.sourceKey,
        initialEp: ep,
        initialPage: page,
      ),
    );
  }

  void goPhotoView(ImageFavorite imageFavorite) {
    // 双击浏览大图
    App.mainNavigatorKey?.currentContext?.to(
      () => ImageFavoritesPhotoView(
        imageFavoritesComic: widget.imageFavoritesComic,
        imageFavoritePro: imageFavorite,
        finalImageFavoritesComicList: widget.finalImageFavoritesComicList,
        goComicInfo: goComicInfo,
        goReaderPage: goReaderPage,
      ),
    );
  }

  void copyTitle() {
    Clipboard.setData(ClipboardData(text: widget.imageFavoritesComic.title));
    App.rootContext.showMessage(message: 'Copy the title successfully'.tl);
  }

  void onLongPress(BuildContext context) {
    var renderBox = context.findRenderObject() as RenderBox;
    var size = renderBox.size;
    var location = renderBox.localToGlobal(
      Offset((size.width - 242) / 2, size.height / 2),
    );
    showMenu(location, context);
  }

  void onSecondaryTap(TapDownDetails details, BuildContext context) {
    showMenu(details.globalPosition, context);
  }

  void showMenu(Offset location, BuildContext context) {
    showMenuX(
      App.rootContext,
      location,
      [
        MenuEntry(
          icon: Icons.chrome_reader_mode_outlined,
          text: 'Details'.tl,
          onClick: () {
            goComicInfo(widget.imageFavoritesComic);
          },
        ),
        MenuEntry(
          icon: Icons.copy,
          text: 'Copy Title'.tl,
          onClick: () {
            copyTitle();
          },
        ),
        MenuEntry(
          icon: Icons.select_all,
          text: 'Select All'.tl,
          onClick: () {
            for (var ele in widget.imageFavoritesComic.sortedImageFavorites) {
              widget.addSelected(ele);
            }
          },
        ),
        MenuEntry(
          icon: Icons.read_more,
          text: 'Photo View'.tl,
          onClick: () {
            goPhotoView(widget.imageFavoritesComic.sortedImageFavorites.first);
          },
        ),
      ],
    );
  }

  @override
  void initState() {
    loadingImageFavoritesComicRes = widget.isRefreshComicList.firstWhereOrNull(
            (e) =>
                e.id == widget.imageFavoritesComic.id &&
                e.sourceKey == widget.imageFavoritesComic.sourceKey) ??
        _LoadingImageFavoritesComicRes(
          isLoaded: false,
          isInvalid: false,
          id: widget.imageFavoritesComic.id,
          sourceKey: widget.imageFavoritesComic.sourceKey,
        );
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    int count = widget.imageFavoritesComic.sortedImageFavorites.length;
    if (!widget.imageFavoritesComic.isAllHasImageKey ||
        !widget.imageFavoritesComic.isAllHasFirstPage) {
      for (var e in widget.imageFavoritesComic.imageFavoritesEp) {
        refreshImageKey(e);
      }
    }
    var enableTranslate = App.locale.languageCode == 'zh';
    String time =
        DateFormat('yyyy-MM-dd HH:mm').format(widget.imageFavoritesComic.time);
    List<String> hotTags = [];
    for (var textWithCount
        in widget.imageFavoritesCompute?.tags ?? <TextWithCount>[]) {
      if (widget.imageFavoritesComic.tags.contains(textWithCount.text)) {
        var enableTranslate = App.locale.languageCode == 'zh';
        var text = enableTranslate
            ? textWithCount.text.translateTagsToCN
            : textWithCount.text;
        if (text.contains(':')) {
          text = text.split(':').last;
        }
        hotTags.add(text);
      }
      if (hotTags.length == 5) {
        break;
      }
    }
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
        onSecondaryTapDown: (detail) => onSecondaryTap(detail, context),
        onLongPress: () => onLongPress(context),
        onDoubleTap: () {
          copyTitle();
        },
        onTap: () {
          if (widget.multiSelectMode) {
            for (var ele in widget.imageFavoritesComic.sortedImageFavorites) {
              widget.addSelected(ele);
            }
          } else {
            // 单击跳转漫画详情
            goComicInfo(widget.imageFavoritesComic);
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
                      widget.imageFavoritesComic.title,
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
                    child: Text(
                        "$count/${widget.imageFavoritesComic.maxPageFromEp}",
                        style: ts.s12),
                  ),
                ],
              ),
            ).paddingHorizontal(16),
            SizedBox(
              height: 145,
              child: CustomScrollView(
                scrollDirection: Axis.horizontal,
                slivers: [
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        ImageFavorite curImageFavorite = widget
                            .imageFavoritesComic.sortedImageFavorites[index];
                        ImageFavoritesEp curImageFavoritesEp = widget
                            .imageFavoritesComic.imageFavoritesEp
                            .firstWhere((e) {
                          return e.ep == curImageFavorite.ep;
                        });
                        bool isSelected =
                            widget.selectedImageFavorites[curImageFavorite] ??
                                false;
                        int curPage = curImageFavorite.page;
                        String pageText = curPage == firstPage
                            ? '@a Cover'
                                .tlParams({"a": curImageFavorite.epName})
                            : curPage.toString();
                        return InkWell(
                          onDoubleTap: () {
                            goPhotoView(curImageFavorite);
                          },
                          onTap: () {
                            // 单击去阅读页面, 跳转到当前点击的page
                            if (widget.multiSelectMode) {
                              widget.addSelected(curImageFavorite);
                            } else {
                              goReaderPage(widget.imageFavoritesComic,
                                  curImageFavorite.ep, curPage);
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
                                    ? Theme.of(context)
                                        .colorScheme
                                        .primaryContainer
                                    : null,
                              ),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4),
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
                                      child: AnimatedImage(
                                        image: ImageFavoritesProvider(
                                            curImageFavorite),
                                        width: 96,
                                        height: 128,
                                        fit: BoxFit.cover,
                                        filterQuality: FilterQuality.medium,
                                        onError: (Object error,
                                            StackTrace? stackTrace) {
                                          if (loadingImageFavoritesComicRes
                                              .isLoaded) {
                                            return;
                                          }
                                          refreshImageKey(curImageFavoritesEp);
                                          hasRefreshImageKeyOnErr = true;
                                        },
                                      )),
                                  Text(
                                    pageText,
                                    style: ts.s10,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  )
                                ],
                              )),
                        );
                      },
                      childCount: count,
                    ),
                  ),
                ],
              ),
            ).paddingHorizontal(8),
            if (loadingImageFavoritesComicRes.isInvalid)
              Row(
                children: [
                  Text(
                      "The comic is invalid, please long press to delete, you can double click the title to copy"
                          .tl,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error, // 设置为红色
                        fontSize: 12,
                      )),
                ],
              ).paddingHorizontal(16),
            Row(
              children: [
                Text(
                  "${"Collection time".tl}:$time | ${widget.imageFavoritesComic.sourceKey}",
                  textAlign: TextAlign.left,
                  style: const TextStyle(
                    fontSize: 12.0,
                  ),
                ).paddingRight(8),
                if (hotTags.isNotEmpty)
                  Expanded(
                    child: Text(
                      hotTags
                          .map((e) => enableTranslate ? e.translateTagsToCN : e)
                          .join(" "),
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 12.0,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
              ],
            ).paddingHorizontal(8).paddingBottom(8),
          ],
        ),
      ),
    );
  }
}
