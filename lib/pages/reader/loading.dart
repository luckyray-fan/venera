part of 'reader.dart';

class ReaderWithLoading extends StatefulWidget {
  const ReaderWithLoading({
    super.key,
    required this.id,
    required this.sourceKey,
    this.initialEp,
    this.initialPage,
  });

  final String id;

  final String sourceKey;

  final int? initialEp;

  final int? initialPage;

  @override
  State<ReaderWithLoading> createState() => _ReaderWithLoadingState();
}

class _ReaderWithLoadingState
    extends LoadingState<ReaderWithLoading, ReaderProps> {
  @override
  Widget buildContent(BuildContext context, ReaderProps data) {
    return Reader(
      type: data.type,
      cid: data.cid,
      name: data.name,
      chapters: data.chapters,
      history: data.history,
      initialChapter: widget.initialEp ?? data.history.ep,
      initialPage: widget.initialPage ?? data.history.page,
      comicDetails: data.comicDetails,
    );
  }

  @override
  Future<Res<ReaderProps>> loadData() async {
    var comicSource = ComicSource.find(widget.sourceKey);
    var history = HistoryManager().findSync(
      widget.id,
      ComicType.fromKey(widget.sourceKey),
    );
    if (comicSource == null) {
      var localComic = LocalManager().find(
        widget.id,
        ComicType.fromKey(widget.sourceKey),
      );
      if (localComic == null) {
        return Res.error("comic not found");
      }
      return Res(
        ReaderProps(
            type: ComicType.fromKey(widget.sourceKey),
            cid: widget.id,
            name: localComic.title,
            chapters: localComic.chapters,
            history: history ??
                History.fromModel(
                  model: localComic,
                  ep: 0,
                  page: 0,
                ),
            comicDetails: localComic),
      );
    } else {
      var comic = await comicSource.loadComicInfo!(widget.id);
      if (comic.error) {
        return Res.fromErrorRes(comic);
      }
      return Res(
        ReaderProps(
            type: ComicType.fromKey(widget.sourceKey),
            cid: widget.id,
            name: comic.data.title,
            chapters: comic.data.chapters,
            history: history ??
                History.fromModel(
                  model: comic.data,
                  ep: 0,
                  page: 0,
                ),
            comicDetails: comic.data),
      );
    }
  }
}

class ReaderProps {
  final ComicType type;

  final String cid;

  final String name;

  final Map<String, String>? chapters;

  final History history;
  // 缺少作者, 现在的作者都是上传者
  final Object comicDetails;

  const ReaderProps({
    required this.type,
    required this.cid,
    required this.name,
    required this.chapters,
    required this.history,
    required this.comicDetails,
  });
}