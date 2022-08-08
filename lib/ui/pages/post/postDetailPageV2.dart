import 'package:dtube_go/utils/globalVariables.dart' as globals;
import 'package:dtube_go/utils/SecureStorage.dart' as sec;
import 'package:dtube_go/bloc/feed/feed_bloc.dart';
import 'package:dtube_go/bloc/feed/feed_event.dart';
import 'package:dtube_go/bloc/feed/feed_repository.dart';
import 'package:dtube_go/bloc/transaction/transaction_bloc.dart';
import 'package:dtube_go/style/ThemeData.dart';
import 'package:dtube_go/ui/pages/feeds/lists/FeedListCarousel.dart';
import 'package:dtube_go/ui/widgets/Suggestions/SuggestedChannels.dart';
import 'package:dtube_go/ui/MainContainer/NavigationContainer.dart';
import 'package:dtube_go/ui/widgets/OverlayWidgets/OverlayIcon.dart';
import 'package:dtube_go/ui/widgets/dtubeLogoPulse/DTubeLogo.dart';
import 'package:dtube_go/ui/widgets/gifts/GiftBoxWidget.dart';
import 'package:dtube_go/ui/widgets/tags/TagChip.dart';
import 'package:dtube_go/utils/friendlyTimestamp.dart';
import 'package:dtube_go/utils/shortBalanceStrings.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_animator/flutter_animator.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:responsive_sizer/responsive_sizer.dart';
import 'package:dtube_go/utils/navigationShortcuts.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:dtube_go/bloc/auth/auth_bloc_full.dart';
import 'package:dtube_go/bloc/settings/settings_bloc_full.dart';
import 'package:dtube_go/bloc/user/user_bloc_full.dart';
import 'package:dtube_go/bloc/postdetails/postdetails_bloc_full.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dtube_go/ui/widgets/players/P2PSourcePlayer.dart';
import 'package:dtube_go/ui/widgets/AccountAvatar.dart';
import 'package:dtube_go/ui/pages/post/widgets/CollapsedDescription.dart';
import 'package:dtube_go/ui/pages/post/widgets/Comments.dart';
import 'package:dtube_go/ui/pages/post/widgets/ReplyButton.dart';
import 'package:dtube_go/ui/pages/post/widgets/VoteButtons.dart';
import 'package:dtube_go/utils/secureStorage.dart';
import 'package:dtube_go/ui/widgets/dtubeLogoPulse/dtubeLoading.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import 'dart:io' show Platform;

class PostDetailPage extends StatefulWidget {
  String link;
  String author;
  bool recentlyUploaded;
  String directFocus;
  VoidCallback? onPop;

  PostDetailPage(
      {required this.link,
      required this.author,
      required this.recentlyUploaded,
      required this.directFocus,
      this.onPop});

  @override
  _PostDetailPageState createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  int reloadCount = 0;
  bool flagged = false;

  Future<bool> _onWillPop() async {
    if (widget.recentlyUploaded) {
      Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
              builder: (context) => MultiBlocProvider(providers: [
                    BlocProvider<UserBloc>(
                      create: (BuildContext context) =>
                          UserBloc(repository: UserRepositoryImpl()),
                    ),
                    BlocProvider<AuthBloc>(
                      create: (BuildContext context) =>
                          AuthBloc(repository: AuthRepositoryImpl()),
                    ),
                  ], child: NavigationContainer())),
          (route) => false);
    } else {
      Navigator.pop(context);
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<PostBloc>(
          create: (BuildContext context) =>
              PostBloc(repository: PostRepositoryImpl())
                ..add(FetchPostEvent(widget.author, widget.link)),
        ),
        BlocProvider<UserBloc>(
            create: (BuildContext context) =>
                UserBloc(repository: UserRepositoryImpl())),
        BlocProvider<SettingsBloc>(
          create: (BuildContext context) =>
              SettingsBloc()..add(FetchSettingsEvent()),
        ),
      ],
      // child: WillPopScope(
      //     onWillPop: _onWillPop,
      child: new WillPopScope(
          onWillPop: () async {
            if (widget.onPop != null) {
              widget.onPop!();
              if (flagged) {
                await Future.delayed(Duration(seconds: 3));
                Phoenix.rebirth(context);
              }
            }

            return true;
          },
          child: Scaffold(
            // resizeToAvoidBottomInset: true,
            extendBodyBehindAppBar: true,
            // backgroundColor: Colors.transparent,
            appBar: kIsWeb
                ? null
                : AppBar(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    toolbarHeight: 28,
                  ),
            body: BlocBuilder<PostBloc, PostState>(builder: (context, state) {
              if (state is PostLoadingState) {
                return Center(
                  child: DtubeLogoPulseWithSubtitle(
                    subtitle: "loading post details...",
                    size: kIsWeb ? 10.w : 30.w,
                  ),
                );
              } else if (state is PostLoadedState) {
                reloadCount++;
                if (!state.post.isFlaggedByUser) {
                  return Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: kIsWeb
                        ? WebPostDetails(
                            post: state.post,
                            directFocus:
                                reloadCount <= 1 ? widget.directFocus : "none",
                            //),
                          )
                        : MobilePostDetails(
                            post: state.post,
                            directFocus:
                                reloadCount <= 1 ? widget.directFocus : "none",
                          ),
                  );
                } else {
                  flagged = true;

                  return Center(
                      child: Text("this post got flagged by you!",
                          style: Theme.of(context).textTheme.headline4));
                }
              } else {
                return Center(
                  child: DtubeLogoPulseWithSubtitle(
                    subtitle: "loading post details...",
                    size: kIsWeb ? 10.w : 30.w,
                  ),
                );
              }
            }),
          )
          //)
          ),
    );
  }
}

class MobilePostDetails extends StatefulWidget {
  final Post post;
  final String directFocus;

  const MobilePostDetails(
      {Key? key, required this.post, required this.directFocus})
      : super(key: key);

  @override
  _MobilePostDetailsState createState() => _MobilePostDetailsState();
}

class _MobilePostDetailsState extends State<MobilePostDetails> {
  late YoutubePlayerController _controller;
  late VideoPlayerController _videocontroller;

  late UserBloc _userBloc;

  late double _defaultVoteWeightPosts = 0;
  late double _defaultVoteWeightComments = 0;
  late double _defaultVoteTipPosts = 0;
  late double _defaultVoteTipComments = 0;

  late bool _fixedDownvoteActivated = true;
  late double _fixedDownvoteWeight = 1;

  late int _currentVT = 0;
  String blockedUsers = "";

  void fetchBlockedUsers() async {
    blockedUsers = await sec.getBlockedUsers();
  }

  @override
  void initState() {
    super.initState();
    fetchBlockedUsers();

    _userBloc = BlocProvider.of<UserBloc>(context);

    _userBloc.add(FetchAccountDataEvent(username: widget.post.author));
    _userBloc.add(FetchDTCVPEvent());

    _controller = YoutubePlayerController(
      initialVideoId: widget.post.videoUrl!,
      params: YoutubePlayerParams(
          showControls: true,
          showFullscreenButton: true,
          desktopMode: kIsWeb ? true : !Platform.isIOS,
          privacyEnhanced: true,
          useHybridComposition: true,
          autoPlay: !(widget.directFocus != "none")),
    );
    _controller.onEnterFullscreen = () {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      print('Entered Fullscreen');
    };
    _controller.onExitFullscreen = () {
      print('Exited Fullscreen');
    };
    _videocontroller =
        VideoPlayerController.asset('assets/videos/firstpage.mp4');
  }

  @override
  void dispose() {
    _controller.pause();
    _controller.close();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const player = YoutubePlayerIFrame();
    return BlocListener<UserBloc, UserState>(
      listener: (context, state) {
        if (state is UserDTCVPLoadedState) {
          setState(() {
            _currentVT = state.vtBalance["v"]!;
          });
        }
      },
      child: YoutubePlayerControllerProvider(
          controller: _controller,
          child: Container(
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.only(top: 5.h),
                child: Stack(
                  children: <Widget>[
                    Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: <Widget>[
                        Column(
                          children: [
                            Container(
                              alignment: Alignment.topRight,
                              margin: EdgeInsets.all(5.0),
                              child: globals.disableAnimations
                                  ? AccountNavigationChip(
                                      author: widget.post.author)
                                  : SlideInDown(
                                      preferences: AnimationPreferences(
                                          offset: Duration(milliseconds: 500)),
                                      child: AccountNavigationChip(
                                          author: widget.post.author),
                                    ),
                            ),
                            globals.disableAnimations
                                ? TitleWidget(
                                    title: widget.post.jsonString!.title)
                                : FadeInLeft(
                                    preferences: AnimationPreferences(
                                        offset: Duration(milliseconds: 700),
                                        duration: Duration(seconds: 1)),
                                    child: TitleWidget(
                                        title: widget.post.jsonString!.title),
                                  ),
                          ],
                        ),
                        widget.post.videoSource == "youtube"
                            ? player
                            : ["ipfs", "sia"].contains(widget.post.videoSource)
                                ? ChewiePlayer(
                                    videoUrl: widget.post.videoUrl!,
                                    autoplay: !(widget.directFocus != "none"),
                                    looping: false,
                                    localFile: false,
                                    controls: true,
                                    usedAsPreview: false,
                                    allowFullscreen: true,
                                    portraitVideoPadding: 5.w,
                                    videocontroller: _videocontroller,
                                    placeholderWidth: 100.w,
                                    placeholderSize: 40.w,
                                  )
                                : Text("no player detected"),
                        SizedBox(
                          height: 2.h,
                        ),
                        FadeIn(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              widget.post.tags.length > 0
                                  ? Row(
                                      children: [
                                        widget.post.jsonString!.oc == 1
                                            ? SizedBox(
                                                width: globalIconSizeSmall,
                                                child: FaIcon(
                                                    FontAwesomeIcons.award,
                                                    size: globalIconSizeSmall))
                                            : SizedBox(width: 0),
                                        Container(
                                          width: 60.w,
                                          height: 5.h,
                                          child: ListView.builder(
                                              scrollDirection: Axis.horizontal,
                                              itemCount:
                                                  widget.post.tags.length,
                                              itemBuilder: (context, index) {
                                                return Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          right: 8.0),
                                                  child: TagChip(
                                                      waitBeforeFadeIn:
                                                          Duration(seconds: 1),
                                                      fadeInFromLeft: true,
                                                      width: 20.w,
                                                      tagName: widget
                                                          .post.tags[index]
                                                          .toString()),
                                                );
                                              }),
                                        ),
                                      ],
                                    )
                                  : SizedBox(height: 0),
                              globals.disableAnimations
                                  ? DtubeCoinsChip(
                                      dist: widget.post.dist,
                                      post: widget.post,
                                    )
                                  : BounceIn(
                                      preferences: AnimationPreferences(
                                          offset: Duration(milliseconds: 1200)),
                                      child: DtubeCoinsChip(
                                        dist: widget.post.dist,
                                        post: widget.post,
                                      ),
                                    ),
                            ],
                          ),
                        ),
// todo refactor twice used code:
                        globals.disableAnimations
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  BlocBuilder<SettingsBloc, SettingsState>(
                                      builder: (context, state) {
                                    if (state is SettingsLoadedState) {
                                      _defaultVoteWeightPosts = double.parse(
                                          state.settings[
                                              settingKey_defaultVotingWeight]!);
                                      _defaultVoteTipPosts = double.parse(
                                          state.settings[
                                              settingKey_defaultVotingWeight]!);
                                      _defaultVoteWeightComments = double.parse(
                                          state.settings[
                                              settingKey_defaultVotingWeightComments]!);
                                      _fixedDownvoteActivated = state.settings[
                                              settingKey_FixedDownvoteActivated] ==
                                          "true";
                                      _fixedDownvoteWeight = double.parse(
                                          state.settings[
                                              settingKey_FixedDownvoteWeight]!);
                                      return BlocProvider<UserBloc>(
                                        create: (BuildContext context) =>
                                            UserBloc(
                                                repository:
                                                    UserRepositoryImpl()),
                                        child: VotingButtons(
                                          author: widget.post.author,
                                          link: widget.post.link,
                                          alreadyVoted:
                                              widget.post.alreadyVoted!,
                                          alreadyVotedDirection: widget
                                              .post.alreadyVotedDirection!,
                                          upvotes: widget.post.upvotes,
                                          downvotes: widget.post.downvotes,
                                          defaultVotingWeight:
                                              _defaultVoteWeightPosts,
                                          defaultVotingTip:
                                              _defaultVoteTipPosts,
                                          scale: 0.8,
                                          isPost: true,
                                          iconColor: globalAlmostWhite,
                                          focusVote: widget.directFocus,
                                          fadeInFromLeft: false,
                                          fixedDownvoteActivated:
                                              _fixedDownvoteActivated,
                                          fixedDownvoteWeight:
                                              _fixedDownvoteWeight,
                                        ),
                                      );
                                    } else {
                                      return SizedBox(height: 0);
                                    }
                                  }),
                                  SizedBox(width: 8),
                                  GiftboxWidget(
                                    receiver: widget.post.author,
                                    link: widget.post.link,
                                    txBloc: BlocProvider.of<TransactionBloc>(
                                        context),
                                  ),
                                ],
                              )
                            : FadeInRight(
                                preferences: AnimationPreferences(
                                    offset: Duration(milliseconds: 200)),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    BlocBuilder<SettingsBloc, SettingsState>(
                                        builder: (context, state) {
                                      if (state is SettingsLoadedState) {
                                        _defaultVoteWeightPosts = double.parse(
                                            state.settings[
                                                settingKey_defaultVotingWeight]!);
                                        _defaultVoteTipPosts = double.parse(state
                                                .settings[
                                            settingKey_defaultVotingWeight]!);
                                        _defaultVoteWeightComments =
                                            double.parse(state.settings[
                                                settingKey_defaultVotingWeightComments]!);
                                        _fixedDownvoteActivated = state
                                                    .settings[
                                                settingKey_FixedDownvoteActivated] ==
                                            "true";
                                        _fixedDownvoteWeight = double.parse(state
                                                .settings[
                                            settingKey_FixedDownvoteWeight]!);
                                        return BlocProvider<UserBloc>(
                                          create: (BuildContext context) =>
                                              UserBloc(
                                                  repository:
                                                      UserRepositoryImpl()),
                                          child: VotingButtons(
                                            author: widget.post.author,
                                            link: widget.post.link,
                                            alreadyVoted:
                                                widget.post.alreadyVoted!,
                                            alreadyVotedDirection: widget
                                                .post.alreadyVotedDirection!,
                                            upvotes: widget.post.upvotes,
                                            downvotes: widget.post.downvotes,
                                            defaultVotingWeight:
                                                _defaultVoteWeightPosts,
                                            defaultVotingTip:
                                                _defaultVoteTipPosts,
                                            scale: 0.8,
                                            isPost: true,
                                            iconColor: globalAlmostWhite,
                                            focusVote: widget.directFocus,
                                            fadeInFromLeft: false,
                                            fixedDownvoteActivated:
                                                _fixedDownvoteActivated,
                                            fixedDownvoteWeight:
                                                _fixedDownvoteWeight,
                                          ),
                                        );
                                      } else {
                                        return SizedBox(height: 0);
                                      }
                                    }),
                                    SizedBox(width: 8),
                                    GiftboxWidget(
                                      receiver: widget.post.author,
                                      link: widget.post.link,
                                      txBloc: BlocProvider.of<TransactionBloc>(
                                          context),
                                    ),
                                  ],
                                ),
                              ),
                        globals.disableAnimations
                            ? CollapsedDescription(
                                startCollapsed: false,
                                description:
                                    widget.post.jsonString!.desc != null
                                        ? widget.post.jsonString!.desc!
                                        : "")
                            : FadeInDown(
                                child: CollapsedDescription(
                                    startCollapsed: false,
                                    description:
                                        widget.post.jsonString!.desc != null
                                            ? widget.post.jsonString!.desc!
                                            : ""),
                              ),
                        globals.disableAnimations
                            ? ShareAndCommentChips(
                                author: widget.post.author,
                                link: widget.post.link,
                                directFocus: widget.directFocus,
                                defaultVoteWeightComments:
                                    _defaultVoteWeightComments,
                              )
                            : FadeInUp(
                                child: ShareAndCommentChips(
                                  author: widget.post.author,
                                  link: widget.post.link,
                                  directFocus: widget.directFocus,
                                  defaultVoteWeightComments:
                                      _defaultVoteWeightComments,
                                ),
                              ),
                        // SizedBox(height: 16),
                        widget.post.comments != null &&
                                widget.post.comments!.length > 0
                            ? globals.disableAnimations
                                ? CommentContainer(
                                    post: widget.post,
                                    defaultVoteWeightComments:
                                        _defaultVoteWeightComments,
                                    currentVT: _currentVT,
                                    defaultVoteTipComments:
                                        _defaultVoteTipComments,
                                    blockedUsers: blockedUsers,
                                    fixedDownvoteActivated:
                                        _fixedDownvoteActivated,
                                    fixedDownvoteWeight: _fixedDownvoteWeight,
                                  )
                                : SlideInLeft(
                                    child: CommentContainer(
                                      post: widget.post,
                                      defaultVoteWeightComments:
                                          _defaultVoteWeightComments,
                                      currentVT: _currentVT,
                                      defaultVoteTipComments:
                                          _defaultVoteTipComments,
                                      blockedUsers: blockedUsers,
                                      fixedDownvoteActivated:
                                          _fixedDownvoteActivated,
                                      fixedDownvoteWeight: _fixedDownvoteWeight,
                                    ),
                                  )
                            : SizedBox(height: 0),

                        BlocProvider<FeedBloc>(
                          create: (context) =>
                              FeedBloc(repository: FeedRepositoryImpl())
                                ..add(FetchSuggestedUsersForPost(
                                    currentUsername: widget.post.author,
                                    tags: widget.post.tags)),
                          child: SuggestedChannels(avatarSize: 18.w),
                        ),
                        BlocProvider<FeedBloc>(
                          create: (context) =>
                              FeedBloc(repository: FeedRepositoryImpl())
                                ..add(FetchSuggestedPostsForPost(
                                    currentUsername: widget.post.author,
                                    tags: widget.post.tags)),
                          child: FeedListCarousel(
                              feedType: 'SuggestedPosts',
                              username: widget.post.author,
                              showAuthor: true,
                              largeFormat: false,
                              heightPerEntry: 20.h,
                              width: 150.w,
                              topPaddingForFirstEntry: 0,
                              sidepadding: 5.w,
                              bottompadding: 0.h,
                              scrollCallback: (bool) {},
                              enableNavigation: true,
                              header: "Suggested Videos"),
                        ),
                        SizedBox(height: 200)
                      ],
                    ),
                  ],
                ),
              ),
            ),
          )),
    );
  }
}

class CommentContainer extends StatelessWidget {
  const CommentContainer({
    Key? key,
    required double defaultVoteWeightComments,
    required int currentVT,
    required double defaultVoteTipComments,
    required this.blockedUsers,
    required bool fixedDownvoteActivated,
    required double fixedDownvoteWeight,
    required this.post,
  })  : _defaultVoteWeightComments = defaultVoteWeightComments,
        _currentVT = currentVT,
        _defaultVoteTipComments = defaultVoteTipComments,
        _fixedDownvoteActivated = fixedDownvoteActivated,
        _fixedDownvoteWeight = fixedDownvoteWeight,
        super(key: key);

  final Post post;
  final double _defaultVoteWeightComments;
  final int _currentVT;
  final double _defaultVoteTipComments;
  final String blockedUsers;
  final bool _fixedDownvoteActivated;
  final double _fixedDownvoteWeight;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100.h,
      child: ListView.builder(
        itemCount: post.comments!.length,
        padding: EdgeInsets.zero,
        itemBuilder: (BuildContext context, int index) => Column(
          children: [
            CommentDisplay(
                post.comments![index],
                _defaultVoteWeightComments,
                _currentVT,
                post.author,
                post.link,
                _defaultVoteTipComments,
                context,
                blockedUsers.split(","),
                _fixedDownvoteActivated,
                _fixedDownvoteWeight),
            SizedBox(height: index == post.comments!.length - 1 ? 200 : 0)
          ],
        ),
      ),
    );
  }
}

class ShareAndCommentChips extends StatelessWidget {
  const ShareAndCommentChips({
    Key? key,
    required this.author,
    required this.directFocus,
    required this.link,
    required double defaultVoteWeightComments,
  })  : _defaultVoteWeightComments = defaultVoteWeightComments,
        super(key: key);

  final String author;
  final String link;
  final double _defaultVoteWeightComments;
  final String directFocus;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Divider(),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InputChip(
              label: FaIcon(FontAwesomeIcons.shareAlt),
              onPressed: () {
                Share.share('https://d.tube/#!/v/' + author + '/' + link);
              },
            ),
            SizedBox(width: 8),
            ReplyButton(
              icon: FaIcon(FontAwesomeIcons.comment),
              author: author,
              link: link,
              parentAuthor: author,
              parentLink: link,
              votingWeight: _defaultVoteWeightComments,
              scale: 1,
              focusOnNewComment: directFocus == "newcomment",
              isMainPost: true,
            ),
          ],
        ),
      ],
    );
  }
}

class DtubeCoinsChip extends StatelessWidget {
  const DtubeCoinsChip({
    Key? key,
    required this.dist,
    required this.post,
  }) : super(key: key);

  final double dist;
  final Post post;
  @override
  Widget build(BuildContext context) {
    return InputChip(
      label: Row(
        children: [
          Text(
            (dist / 100).round().toString(),
            style: Theme.of(context).textTheme.headline5,
          ),
          Padding(
            padding: EdgeInsets.only(left: 2.w),
            child: DTubeLogoShadowed(size: 5.w),
          ),
        ],
      ),
      onPressed: () {
        showDialog<String>(
          context: context,
          builder: (BuildContext context) => VotesOverview(post: post),
        );
      },
    );
  }
}

class TitleWidget extends StatelessWidget {
  const TitleWidget({
    Key? key,
    required this.title,
  }) : super(key: key);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.topLeft,
      padding: EdgeInsets.all(10.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.headline5,
      ),
    );
  }
}

class AccountNavigationChip extends StatelessWidget {
  const AccountNavigationChip({
    Key? key,
    required this.author,
  }) : super(key: key);

  final String author;

  @override
  Widget build(BuildContext context) {
    return InputChip(
      label: AccountAvatarBase(
        username: author,
        avatarSize: 12.w,
        showVerified: true,
        showName: true,
        nameFontSizeMultiply: 0.8,
        width: 35.w,
        height: 5.h,
      ),
      onPressed: () {
        navigateToUserDetailPage(context, author, () {});
      },
    );
  }
}

class WebPostDetails extends StatefulWidget {
  final Post post;
  final String directFocus;

  const WebPostDetails(
      {Key? key, required this.post, required this.directFocus})
      : super(key: key);

  @override
  _WebPostDetailsState createState() => _WebPostDetailsState();
}

class _WebPostDetailsState extends State<WebPostDetails> {
  late YoutubePlayerController _controller;
  late VideoPlayerController _videocontroller;

  late UserBloc _userBloc;

  late double _defaultVoteWeightPosts = 0;
  late double _defaultVoteWeightComments = 0;
  late double _defaultVoteTipPosts = 0;
  late double _defaultVoteTipComments = 0;

  late bool _fixedDownvoteActivated = true;
  late double _fixedDownvoteWeight = 1;

  late int _currentVT = 0;
  String blockedUsers = "";

  void fetchBlockedUsers() async {
    blockedUsers = await sec.getBlockedUsers();
  }

  @override
  void initState() {
    super.initState();
    fetchBlockedUsers();

    _userBloc = BlocProvider.of<UserBloc>(context);

    _userBloc.add(FetchAccountDataEvent(username: widget.post.author));
    _userBloc.add(FetchDTCVPEvent());

    _controller = YoutubePlayerController(
      initialVideoId: widget.post.videoUrl!,
      params: YoutubePlayerParams(
          showControls: true,
          showFullscreenButton: true,
          desktopMode: kIsWeb ? true : !Platform.isIOS,
          privacyEnhanced: true,
          useHybridComposition: true,
          autoPlay: !(widget.directFocus != "none")),
    );
    _controller.onEnterFullscreen = () {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      print('Entered Fullscreen');
    };
    _controller.onExitFullscreen = () {
      print('Exited Fullscreen');
    };
    _videocontroller =
        VideoPlayerController.asset('assets/videos/firstpage.mp4');
  }

  @override
  void dispose() {
    _controller.pause();
    _controller.close();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const player = YoutubePlayerIFrame();
    return BlocListener<UserBloc, UserState>(
      listener: (context, state) {
        if (state is UserDTCVPLoadedState) {
          setState(() {
            _currentVT = state.vtBalance["v"]!;
          });
        }
      },
      child: YoutubePlayerControllerProvider(
          controller: _controller,
          child: Container(
              child: VisibilityDetector(
            key: Key('post-details' + widget.post.link),
            onVisibilityChanged: (visibilityInfo) {
              var visiblePercentage = visibilityInfo.visibleFraction * 100;
              if (visiblePercentage < 1) {
                _controller.pause();
                _videocontroller.pause();
              }
              if (visiblePercentage > 90) {
                _controller.play();
                _videocontroller.play();
              }
            },
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.only(top: 5.h),
                child: Stack(
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: <Widget>[
                          Column(
                            children: [
                              Container(
                                  alignment: Alignment.topRight,
                                  margin: EdgeInsets.all(5.0),
                                  child: globals.disableAnimations
                                      ? AccountNavigationChip(
                                          author: widget.post.author)
                                      : SlideInDown(
                                          preferences: AnimationPreferences(
                                              offset:
                                                  Duration(milliseconds: 500)),
                                          child: AccountNavigationChip(
                                              author: widget.post.author))),
                              globals.disableAnimations
                                  ? TitleWidget(
                                      title: widget.post.jsonString!.title)
                                  : FadeInLeft(
                                      preferences: AnimationPreferences(
                                          offset: Duration(milliseconds: 700),
                                          duration: Duration(seconds: 1)),
                                      child: TitleWidget(
                                          title:
                                              widget.post.jsonString!.title)),
                            ],
                          ),
                          Container(
                            height: 50.h,
                            width: 50.w,
                            child: widget.post.videoSource == "youtube"
                                ? player
                                : ["ipfs", "sia"]
                                        .contains(widget.post.videoSource)
                                    ? ChewiePlayer(
                                        videoUrl: widget.post.videoUrl!,
                                        autoplay:
                                            !(widget.directFocus != "none"),
                                        looping: false,
                                        localFile: false,
                                        controls: true,
                                        usedAsPreview: false,
                                        allowFullscreen: true,
                                        portraitVideoPadding: 5.w,
                                        videocontroller: _videocontroller,
                                        placeholderWidth: 40.w,
                                        placeholderSize: 20.w,
                                      )
                                    : Text("no player detected"),
                          ),
                          FadeIn(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                widget.post.tags.length > 0
                                    ? Row(
                                        children: [
                                          widget.post.jsonString!.oc == 1
                                              ? SizedBox(
                                                  width: globalIconSizeSmall,
                                                  child: FaIcon(
                                                      FontAwesomeIcons.award,
                                                      size:
                                                          globalIconSizeSmall))
                                              : SizedBox(width: 0),
                                          Container(
                                            width: 60.w,
                                            height: 5.h,
                                            child: ListView.builder(
                                                scrollDirection:
                                                    Axis.horizontal,
                                                itemCount:
                                                    widget.post.tags.length,
                                                itemBuilder: (context, index) {
                                                  return Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                            right: 8.0),
                                                    child: TagChip(
                                                        waitBeforeFadeIn:
                                                            Duration(
                                                                seconds: 1),
                                                        fadeInFromLeft: true,
                                                        width: 10.w,
                                                        tagName: widget
                                                            .post.tags[index]
                                                            .toString()),
                                                  );
                                                }),
                                          ),
                                        ],
                                      )
                                    : SizedBox(height: 0),
                                globals.disableAnimations
                                    ? DtubeCoinsChip(
                                        dist: widget.post.dist,
                                        post: widget.post,
                                      )
                                    : BounceIn(
                                        preferences: AnimationPreferences(
                                            offset:
                                                Duration(milliseconds: 1200)),
                                        child: Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: DtubeCoinsChip(
                                              dist: widget.post.dist,
                                              post: widget.post,
                                            )),
                                      ),
                              ],
                            ),
                          ),
// refactor twice used code..
                          globals.disableAnimations
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    BlocBuilder<SettingsBloc, SettingsState>(
                                        builder: (context, state) {
                                      if (state is SettingsLoadedState) {
                                        _defaultVoteWeightPosts = double.parse(
                                            state.settings[
                                                settingKey_defaultVotingWeight]!);
                                        _defaultVoteTipPosts = double.parse(state
                                                .settings[
                                            settingKey_defaultVotingWeight]!);
                                        _defaultVoteWeightComments =
                                            double.parse(state.settings[
                                                settingKey_defaultVotingWeightComments]!);
                                        _fixedDownvoteActivated = state
                                                    .settings[
                                                settingKey_FixedDownvoteActivated] ==
                                            "true";
                                        _fixedDownvoteWeight = double.parse(state
                                                .settings[
                                            settingKey_FixedDownvoteWeight]!);
                                        return BlocProvider<UserBloc>(
                                          create: (BuildContext context) =>
                                              UserBloc(
                                                  repository:
                                                      UserRepositoryImpl()),
                                          child: VotingButtons(
                                            author: widget.post.author,
                                            link: widget.post.link,
                                            alreadyVoted:
                                                widget.post.alreadyVoted!,
                                            alreadyVotedDirection: widget
                                                .post.alreadyVotedDirection!,
                                            upvotes: widget.post.upvotes,
                                            downvotes: widget.post.downvotes,
                                            defaultVotingWeight:
                                                _defaultVoteWeightPosts,
                                            defaultVotingTip:
                                                _defaultVoteTipPosts,
                                            scale: 0.8,
                                            isPost: true,
                                            iconColor: globalAlmostWhite,
                                            focusVote: widget.directFocus,
                                            fadeInFromLeft: false,
                                            fixedDownvoteActivated:
                                                _fixedDownvoteActivated,
                                            fixedDownvoteWeight:
                                                _fixedDownvoteWeight,
                                          ),
                                        );
                                      } else {
                                        return SizedBox(height: 0);
                                      }
                                    }),
                                    SizedBox(width: 8),
                                    GiftboxWidget(
                                      receiver: widget.post.author,
                                      link: widget.post.link,
                                      txBloc: BlocProvider.of<TransactionBloc>(
                                          context),
                                    ),
                                  ],
                                )
                              : FadeInRight(
                                  preferences: AnimationPreferences(
                                      offset: Duration(milliseconds: 200)),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      BlocBuilder<SettingsBloc, SettingsState>(
                                          builder: (context, state) {
                                        if (state is SettingsLoadedState) {
                                          _defaultVoteWeightPosts =
                                              double.parse(state.settings[
                                                  settingKey_defaultVotingWeight]!);
                                          _defaultVoteTipPosts = double.parse(state
                                                  .settings[
                                              settingKey_defaultVotingWeight]!);
                                          _defaultVoteWeightComments =
                                              double.parse(state.settings[
                                                  settingKey_defaultVotingWeightComments]!);
                                          _fixedDownvoteActivated = state
                                                      .settings[
                                                  settingKey_FixedDownvoteActivated] ==
                                              "true";
                                          _fixedDownvoteWeight = double.parse(state
                                                  .settings[
                                              settingKey_FixedDownvoteWeight]!);
                                          return BlocProvider<UserBloc>(
                                            create: (BuildContext context) =>
                                                UserBloc(
                                                    repository:
                                                        UserRepositoryImpl()),
                                            child: VotingButtons(
                                              author: widget.post.author,
                                              link: widget.post.link,
                                              alreadyVoted:
                                                  widget.post.alreadyVoted!,
                                              alreadyVotedDirection: widget
                                                  .post.alreadyVotedDirection!,
                                              upvotes: widget.post.upvotes,
                                              downvotes: widget.post.downvotes,
                                              defaultVotingWeight:
                                                  _defaultVoteWeightPosts,
                                              defaultVotingTip:
                                                  _defaultVoteTipPosts,
                                              scale: 0.8,
                                              isPost: true,
                                              iconColor: globalAlmostWhite,
                                              focusVote: widget.directFocus,
                                              fadeInFromLeft: false,
                                              fixedDownvoteActivated:
                                                  _fixedDownvoteActivated,
                                              fixedDownvoteWeight:
                                                  _fixedDownvoteWeight,
                                            ),
                                          );
                                        } else {
                                          return SizedBox(height: 0);
                                        }
                                      }),
                                      SizedBox(width: 8),
                                      GiftboxWidget(
                                        receiver: widget.post.author,
                                        link: widget.post.link,
                                        txBloc:
                                            BlocProvider.of<TransactionBloc>(
                                                context),
                                      ),
                                    ],
                                  ),
                                ),
                          globals.disableAnimations
                              ? CollapsedDescription(
                                  startCollapsed: true,
                                  description:
                                      widget.post.jsonString!.desc != null
                                          ? widget.post.jsonString!.desc!
                                          : "")
                              : FadeInDown(
                                  child: CollapsedDescription(
                                      startCollapsed: true,
                                      description:
                                          widget.post.jsonString!.desc != null
                                              ? widget.post.jsonString!.desc!
                                              : ""),
                                ),
                          globals.disableAnimations
                              ? ShareAndCommentChips(
                                  author: widget.post.author,
                                  link: widget.post.link,
                                  directFocus: widget.directFocus,
                                  defaultVoteWeightComments:
                                      _defaultVoteWeightComments,
                                )
                              : FadeInUp(
                                  child: ShareAndCommentChips(
                                  author: widget.post.author,
                                  link: widget.post.link,
                                  directFocus: widget.directFocus,
                                  defaultVoteWeightComments:
                                      _defaultVoteWeightComments,
                                )),
                          // SizedBox(height: 16),
                          widget.post.comments != null &&
                                  widget.post.comments!.length > 0
                              ? globals.disableAnimations
                                  ? CommentContainer(
                                      post: widget.post,
                                      defaultVoteWeightComments:
                                          _defaultVoteWeightComments,
                                      currentVT: _currentVT,
                                      defaultVoteTipComments:
                                          _defaultVoteTipComments,
                                      blockedUsers: blockedUsers,
                                      fixedDownvoteActivated:
                                          _fixedDownvoteActivated,
                                      fixedDownvoteWeight: _fixedDownvoteWeight,
                                    )
                                  : SlideInLeft(
                                      child: CommentContainer(
                                      post: widget.post,
                                      defaultVoteWeightComments:
                                          _defaultVoteWeightComments,
                                      currentVT: _currentVT,
                                      defaultVoteTipComments:
                                          _defaultVoteTipComments,
                                      blockedUsers: blockedUsers,
                                      fixedDownvoteActivated:
                                          _fixedDownvoteActivated,
                                      fixedDownvoteWeight: _fixedDownvoteWeight,
                                    ))
                              : SizedBox(height: 0),

                          BlocProvider<FeedBloc>(
                            create: (context) =>
                                FeedBloc(repository: FeedRepositoryImpl())
                                  ..add(FetchSuggestedUsersForPost(
                                    currentUsername: widget.post.author,
                                    tags: widget.post.tags,
                                  )),
                            child: SuggestedChannels(
                              avatarSize: 5.w,
                            ),
                          ),
                          BlocProvider<FeedBloc>(
                            create: (context) =>
                                FeedBloc(repository: FeedRepositoryImpl())
                                  ..add(FetchSuggestedPostsForPost(
                                      currentUsername: widget.post.author,
                                      tags: widget.post.tags)),
                            child: FeedListCarousel(
                                feedType: 'SuggestedPosts',
                                username: widget.post.author,
                                showAuthor: true,
                                largeFormat: false,
                                heightPerEntry: 30.h,
                                width: 150.w,
                                topPaddingForFirstEntry: 0,
                                sidepadding: 5.w,
                                bottompadding: 0.h,
                                scrollCallback: (bool) {},
                                enableNavigation: true,
                                header: "Suggested Videos"),
                          ),
                          SizedBox(height: 200)
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ))),
    );
  }
}

class VotesOverview extends StatefulWidget {
  VotesOverview({
    Key? key,
    required this.post,
  }) : super(key: key);
  Post post;

  @override
  _VotesOverviewState createState() => _VotesOverviewState();
}

class _VotesOverviewState extends State<VotesOverview> {
  List<Votes> _allVotes = [];

  @override
  void initState() {
    super.initState();
    _allVotes = widget.post.upvotes!;
    if (widget.post.downvotes != null) {
      _allVotes = _allVotes + widget.post.downvotes!;
    }
    // sorting the list would be perhaps useful
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20.0))),
      backgroundColor: globalAlmostBlack,
      content: Builder(
        builder: (context) {
          return SingleChildScrollView(
            child: Container(
              height: 45.h,
              width: 90.w,
              child: ListView.builder(
                itemCount: _allVotes.length,
                itemBuilder: (BuildContext context, int index) {
                  return Container(
                      height: 10.h,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          InkWell(
                            onTap: () {
                              navigateToUserDetailPage(
                                  context, _allVotes[index].u, () {});
                            },
                            child: Row(
                              children: [
                                Container(
                                    height: 10.w,
                                    width: 10.w,
                                    child: AccountIconBase(
                                      avatarSize: 10.w,
                                      showVerified: true,
                                      username: _allVotes[index].u,
                                    )),
                                SizedBox(width: 2.w),
                                Container(
                                  width: 30.w,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _allVotes[index].u,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyText1,
                                      ),
                                      Text(
                                        TimeAgo.timeInAgoTSShort(
                                            _allVotes[index].ts),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyText2,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          FaIcon(_allVotes[index].vt > 0
                              ? FontAwesomeIcons.heart
                              : FontAwesomeIcons.flag),
                          Container(
                            width: 20.w,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        Text(
                                          (_allVotes[index].claimable != null
                                              ? shortDTC(_allVotes[index]
                                                  .claimable!
                                                  .floor())
                                              : "0"),
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyText1,
                                        ),
                                        Container(
                                          width: 5.w,
                                          child: Center(
                                            child: DTubeLogoShadowed(size: 5.w),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        Text(
                                          shortVP(_allVotes[index].vt),
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyText1,
                                        ),
                                        Container(
                                          width: 5.w,
                                          child: Center(
                                            child: ShadowedIcon(
                                              icon: FontAwesomeIcons.bolt,
                                              shadowColor: Colors.black,
                                              color: globalAlmostWhite,
                                              size: 5.w,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ));
                },
              ),
            ),
            // ),
          );
        },
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: <Widget>[
        InputChip(
          backgroundColor: globalRed,
          onPressed: () async {
            Navigator.of(context).pop();
          },
          label: Text(
            'Close',
            style: Theme.of(context).textTheme.headline5,
          ),
        ),
      ],
    );
  }
}
