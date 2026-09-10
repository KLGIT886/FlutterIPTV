import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';

part 'app_strings_zh.dart';
part 'app_strings_en.dart';

class AppStrings {
  final Locale locale;
  final Map<String, String> _localizedValues;

  AppStrings(this.locale, this._localizedValues);

  static AppStrings? of(BuildContext context) {
    return Localizations.of<AppStrings>(context, AppStrings);
  }

  static const LocalizationsDelegate<AppStrings> delegate =
      _AppStringsDelegate();

  String get playlistManager => _localizedValues['playlistManager']!;
  String get playlistList => _localizedValues['playlistList']!;
  String get goToHomeToAdd => _localizedValues['goToHomeToAdd']!;
  String get addNewPlaylist => _localizedValues['addNewPlaylist']!;
  String get playlistName => _localizedValues['playlistName']!;
  String get playlistUrl => _localizedValues['playlistUrl']!;
  String get addFromUrl => _localizedValues['addFromUrl']!;
  String get fromFile => _localizedValues['fromFile']!;
  String get importing => _localizedValues['importing']!;
  String get noPlaylists => _localizedValues['noPlaylists']!;
  String get addFirstPlaylist => _localizedValues['addFirstPlaylist']!;
  String get deletePlaylist => _localizedValues['deletePlaylist']!;
  String get deleteConfirmation => _localizedValues['deleteConfirmation']!;
  String get cancel => _localizedValues['cancel']!;
  String get delete => _localizedValues['delete']!;
  String get actions => _localizedValues['actions']!;
  String get settings => _localizedValues['settings']!;
  String get language => _localizedValues['language']!;
  String get general => _localizedValues['general']!;
  String get followSystem => _localizedValues['followSystem']!;
  String get languageFollowSystem => _localizedValues['languageFollowSystem']!;
  String get theme => _localizedValues['theme']!;
  String get themeDark => _localizedValues['themeDark']!;
  String get themeLight => _localizedValues['themeLight']!;
  String get themeSystem => _localizedValues['themeSystem']!;
  String get themeChanged => _localizedValues['themeChanged']!;
  String get fontFamily => _localizedValues['fontFamily']!;
  String get fontFamilyDesc => _localizedValues['fontFamilyDesc']!;
  String get fontChanged => _localizedValues['fontChanged']!;
  String get homeFontSize => _localizedValues['homeFontSize']!;
  String get homeFontSizeDesc => _localizedValues['homeFontSizeDesc']!;
  String get homeFontSizeSet => _localizedValues['homeFontSizeSet']!;
  String get unknown => _localizedValues['unknown']!;
  String get save => _localizedValues['save']!;
  String get error => _localizedValues['error']!;
  String get success => _localizedValues['success']!;
  String get active => _localizedValues['active']!;
  String get refresh => _localizedValues['refresh']!;
  String get updated => _localizedValues['updated']!;
  String get version => _localizedValues['version']!;
  String get categories => _localizedValues['categories']!;
  String get allChannels => _localizedValues['allChannels']!;
  String get channels => _localizedValues['channels']!;
  String get noChannelsFound => _localizedValues['noChannelsFound']!;
  String get removeFavorites => _localizedValues['removeFavorites']!;
  String get addFavorites => _localizedValues['addFavorites']!;
  String get channelInfo => _localizedValues['channelInfo']!;
  String get playback => _localizedValues['playback']!;
  String get autoPlay => _localizedValues['autoPlay']!;
  String get autoPlaySubtitle => _localizedValues['autoPlaySubtitle']!;
  String get hardwareDecoding => _localizedValues['hardwareDecoding']!;
  String get hardwareDecodingSubtitle =>
      _localizedValues['hardwareDecodingSubtitle']!;
  String get bufferSize => _localizedValues['bufferSize']!;
  String get seconds => _localizedValues['seconds']!;
  String get playlists => _localizedValues['playlists']!;
  String get autoRefresh => _localizedValues['autoRefresh']!;
  String get autoRefreshSubtitle => _localizedValues['autoRefreshSubtitle']!;
  String get refreshInterval => _localizedValues['refreshInterval']!;
  String get hours => _localizedValues['hours']!;
  String get days => _localizedValues['days']!;
  String get day => _localizedValues['day']!;
  String get rememberLastChannel => _localizedValues['rememberLastChannel']!;
  String get rememberLastChannelSubtitle =>
      _localizedValues['rememberLastChannelSubtitle']!;
  String get epg => _localizedValues['epg']!;
  String get enableEpg => _localizedValues['enableEpg']!;
  String get enableEpgSubtitle => _localizedValues['enableEpgSubtitle']!;
  String get epgUrl => _localizedValues['epgUrl']!;
  String get notConfigured => _localizedValues['notConfigured']!;
  String get parentalControl => _localizedValues['parentalControl']!;
  String get enableParentalControl =>
      _localizedValues['enableParentalControl']!;
  String get enableParentalControlSubtitle =>
      _localizedValues['enableParentalControlSubtitle']!;
  String get changePin => _localizedValues['changePin']!;
  String get changePinSubtitle => _localizedValues['changePinSubtitle']!;
  String get about => _localizedValues['about']!;
  String get platform => _localizedValues['platform']!;
  String get resetAllSettings => _localizedValues['resetAllSettings']!;
  String get resetSettingsSubtitle =>
      _localizedValues['resetSettingsSubtitle']!;
  String get enterEpgUrl => _localizedValues['enterEpgUrl']!;
  String get setPin => _localizedValues['setPin']!;
  String get enterPin => _localizedValues['enterPin']!;
  String get resetSettings => _localizedValues['resetSettings']!;
  String get resetConfirm => _localizedValues['resetConfirm']!;
  String get reset => _localizedValues['reset']!;
  String get pleaseEnterPlaylistName =>
      _localizedValues['pleaseEnterPlaylistName']!;
  String get pleaseEnterPlaylistUrl =>
      _localizedValues['pleaseEnterPlaylistUrl']!;
  String get playlistAdded => _localizedValues['playlistAdded']!;
  String get playlistRefreshed => _localizedValues['playlistRefreshed']!;
  String get playlistRefreshFailed =>
      _localizedValues['playlistRefreshFailed']!;
  String get playlistDeleted => _localizedValues['playlistDeleted']!;
  String get playlistImported => _localizedValues['playlistImported']!;
  String get urlCopied => _localizedValues['urlCopied']!;
  String get errorPickingFile => _localizedValues['errorPickingFile']!;
  String get minutesAgo => _localizedValues['minutesAgo']!;
  String get hoursAgo => _localizedValues['hoursAgo']!;
  String get daysAgo => _localizedValues['daysAgo']!;
  String get live => _localizedValues['live']!;
  String get buffering => _localizedValues['buffering']!;
  String get paused => _localizedValues['paused']!;
  String get loading => _localizedValues['loading']!;
  String get playbackError => _localizedValues['playbackError']!;
  String get retry => _localizedValues['retry']!;
  String get initFailed => _localizedValues['initFailed']!;
  String get retrying => _localizedValues['retrying']!;
  String get continueAnyway => _localizedValues['continueAnyway']!;
  String get goBack => _localizedValues['goBack']!;
  String get playbackSettings => _localizedValues['playbackSettings']!;
  String get playbackSpeed => _localizedValues['playbackSpeed']!;
  String get shortcutsHint => _localizedValues['shortcutsHint']!;
  String get lotusIptv => _localizedValues['lotusIptv']!;
  String get professionalIptvPlayer =>
      _localizedValues['professionalIptvPlayer']!;
  String get searchChannels => _localizedValues['searchChannels']!;
  String get searchHint => _localizedValues['searchHint']!;
  String get typeToSearch => _localizedValues['typeToSearch']!;
  String get popularCategories => _localizedValues['popularCategories']!;
  String get sports => _localizedValues['sports']!;
  String get movies => _localizedValues['movies']!;
  String get news => _localizedValues['news']!;
  String get music => _localizedValues['music']!;
  String get kids => _localizedValues['kids']!;
  String get noResultsFound => _localizedValues['noResultsFound']!;
  String get noChannelsMatch => _localizedValues['noChannelsMatch']!;
  String get resultsFor => _localizedValues['resultsFor']!;
  String get favorites => _localizedValues['favorites']!;
  String get clearAll => _localizedValues['clearAll']!;
  String get noFavoritesYet => _localizedValues['noFavoritesYet']!;
  String get favoritesHint => _localizedValues['favoritesHint']!;
  String get noProgramInfo => _localizedValues['noProgramInfo']!;
  String get browseChannels => _localizedValues['browseChannels']!;
  String get removedFromFavorites => _localizedValues['removedFromFavorites']!;
  String get undo => _localizedValues['undo']!;
  String get clearAllFavorites => _localizedValues['clearAllFavorites']!;
  String get clearFavoritesConfirm =>
      _localizedValues['clearFavoritesConfirm']!;
  String get allFavoritesCleared => _localizedValues['allFavoritesCleared']!;
  String get home => _localizedValues['home']!;
  String get managePlaylists => _localizedValues['managePlaylists']!;
  String get noPlaylistsYet => _localizedValues['noPlaylistsYet']!;
  String get addFirstPlaylistHint => _localizedValues['addFirstPlaylistHint']!;
  String get addPlaylist => _localizedValues['addPlaylist']!;
  String get totalChannels => _localizedValues['totalChannels']!;

  // New translations
  String get volumeNormalization => _localizedValues['volumeNormalization']!;
  String get volumeNormalizationSubtitle =>
      _localizedValues['volumeNormalizationSubtitle']!;
  String get volumeBoost => _localizedValues['volumeBoost']!;
  String get noBoost => _localizedValues['noBoost']!;
  String get checkUpdate => _localizedValues['checkUpdate']!;
  String get checkUpdateSubtitle => _localizedValues['checkUpdateSubtitle']!;
  String get decodingMode => _localizedValues['decodingMode']!;
  String get decodingModeAuto => _localizedValues['decodingModeAuto']!;
  String get decodingModeHardware => _localizedValues['decodingModeHardware']!;
  String get decodingModeSoftware => _localizedValues['decodingModeSoftware']!;
  String get decodingModeAutoDesc => _localizedValues['decodingModeAutoDesc']!;
  String get decodingModeHardwareDesc =>
      _localizedValues['decodingModeHardwareDesc']!;
  String get decodingModeSoftwareDesc =>
      _localizedValues['decodingModeSoftwareDesc']!;
  String get channelMergeRule => _localizedValues['channelMergeRule']!;
  String get channelMergeRuleSubtitle => _localizedValues['channelMergeRuleSubtitle']!;
  String get channelMergeRuleSet => _localizedValues['channelMergeRuleSet']!;
  String get mergeByName => _localizedValues['mergeByName']!;
  String get mergeByNameDesc => _localizedValues['mergeByNameDesc']!;
  String get mergeByNameGroup => _localizedValues['mergeByNameGroup']!;
  String get mergeByNameGroupDesc => _localizedValues['mergeByNameGroupDesc']!;
  String get volumeBoostLow => _localizedValues['volumeBoostLow']!;
  String get volumeBoostSlightLow => _localizedValues['volumeBoostSlightLow']!;
  String get volumeBoostNormal => _localizedValues['volumeBoostNormal']!;
  String get volumeBoostSlightHigh =>
      _localizedValues['volumeBoostSlightHigh']!;
  String get volumeBoostHigh => _localizedValues['volumeBoostHigh']!;
  String get chinese => _localizedValues['chinese']!;
  String get english => _localizedValues['english']!;
  String get scanToImport => _localizedValues['scanToImport']!;
  String get importingPlaylist => _localizedValues['importingPlaylist']!;
  String get importSuccess => _localizedValues['importSuccess']!;
  String get importFailed => _localizedValues['importFailed']!;
  String get serverStartFailed => _localizedValues['serverStartFailed']!;
  String get processing => _localizedValues['processing']!;
  String get testChannel => _localizedValues['testChannel']!;
  String get unavailable => _localizedValues['unavailable']!;
  
  // User-Agent settings
  String get userAgent => _localizedValues['userAgent']!;
  String get userAgentSubtitle => _localizedValues['userAgentSubtitle']!;
  String get userAgentPreset => _localizedValues['userAgentPreset']!;
  String get userAgentCustom => _localizedValues['userAgentCustom']!;
  String get userAgentCustomHint => _localizedValues['userAgentCustomHint']!;
  String get userAgentSaved => _localizedValues['userAgentSaved']!;
  String get userAgentReset => _localizedValues['userAgentReset']!;
  String get userAgentScanQR => _localizedValues['userAgentScanQR']!;
  String get userAgentScanQRHint => _localizedValues['userAgentScanQRHint']!;
  String get userAgentPresetWget => _localizedValues['userAgentPresetWget']!;
  String get userAgentPresetChromeWin => _localizedValues['userAgentPresetChromeWin']!;
  String get userAgentPresetChromeMac => _localizedValues['userAgentPresetChromeMac']!;
  String get userAgentPresetFirefox => _localizedValues['userAgentPresetFirefox']!;
  String get userAgentPresetSafari => _localizedValues['userAgentPresetSafari']!;
  String get userAgentPresetEdge => _localizedValues['userAgentPresetEdge']!;
  String get userAgentPresetVLC => _localizedValues['userAgentPresetVLC']!;
  String get userAgentPresetFFmpeg => _localizedValues['userAgentPresetFFmpeg']!;
  String get userAgentPresetAndroid => _localizedValues['userAgentPresetAndroid']!;
  String get userAgentPresetIOS => _localizedValues['userAgentPresetIOS']!;
  String get userAgentPresetCustom => _localizedValues['userAgentPresetCustom']!;
  String get showUserAgent => _localizedValues['showUserAgent']!;
  String get showUserAgentSubtitle => _localizedValues['showUserAgentSubtitle']!;
  String get userAgentDisplayEnabled => _localizedValues['userAgentDisplayEnabled']!;
  String get userAgentDisplayDisabled => _localizedValues['userAgentDisplayDisabled']!;
  String get localFile => _localizedValues['localFile']!;

  // Backup and Restore
  String get backupAndRestore => _localizedValues['backupAndRestore']!;
  String get localBackup => _localizedValues['localBackup']!;
  String get webdavBackup => _localizedValues['webdavBackup']!;
  String get createBackup => _localizedValues['createBackup']!;
  String get restoreBackup => _localizedValues['restoreBackup']!;
  String get backupList => _localizedValues['backupList']!;
  String get noBackupsYet => _localizedValues['noBackupsYet']!;
  String get backupCreated => _localizedValues['backupCreated']!;
  String get backupFailed => _localizedValues['backupFailed']!;
  String get restoreSuccess => _localizedValues['restoreSuccess']!;
  String get restoreFailed => _localizedValues['restoreFailed']!;
  String get restoreWarning => _localizedValues['restoreWarning']!;
  String get restoreWarningMessage => _localizedValues['restoreWarningMessage']!;
  String get restoreConfirm => _localizedValues['restoreConfirm']!;
  String get backupInfo => _localizedValues['backupInfo']!;
  String get webdavConfig => _localizedValues['webdavConfig']!;
  String get serverUrl => _localizedValues['serverUrl']!;
  String get username => _localizedValues['username']!;
  String get password => _localizedValues['password']!;
  String get remotePath => _localizedValues['remotePath']!;
  String get testConnection => _localizedValues['testConnection']!;
  String get connectionSuccess => _localizedValues['connectionSuccess']!;
  String get connectionFailed => _localizedValues['connectionFailed']!;
  String get uploadToWebdav => _localizedValues['uploadToWebdav']!;
  String get downloadFromWebdav => _localizedValues['downloadFromWebdav']!;
  String get backupSize => _localizedValues['backupSize']!;
  String get backupDate => _localizedValues['backupDate']!;
  String get deleteBackup => _localizedValues['deleteBackup']!;
  String get deleteBackupConfirm => _localizedValues['deleteBackupConfirm']!;
  String get backupDeleted => _localizedValues['backupDeleted']!;
  String get creating => _localizedValues['creating']!;
  String get restoring => _localizedValues['restoring']!;
  String get uploading => _localizedValues['uploading']!;
  String get downloading => _localizedValues['downloading']!;
  String get versionIncompatible => _localizedValues['versionIncompatible']!;
  String get versionIncompatibleMessage => _localizedValues['versionIncompatibleMessage']!;
  String get willAutoMigrate => _localizedValues['willAutoMigrate']!;
  String get remoteConfig => _localizedValues['remoteConfig']!;
  String get scanToConfig => _localizedValues['scanToConfig']!;
  String get configTimeout => _localizedValues['configTimeout']!;
  String get configReceived => _localizedValues['configReceived']!;
  String get appVersion => _localizedValues['appVersion']!;
  String get backupTime => _localizedValues['backupTime']!;
  String get browse => _localizedValues['browse']!;
  String get webdavConfigTitle => _localizedValues['webdavConfigTitle']!;
  String get webdavConfigStep1 => _localizedValues['webdavConfigStep1']!;
  String get webdavConfigStep2 => _localizedValues['webdavConfigStep2']!;
  String get webdavConfigStep3 => _localizedValues['webdavConfigStep3']!;
  String get preparingConfig => _localizedValues['preparingConfig']!;
  String get configReady => _localizedValues['configReady']!;
  String get backupAndRestoreSubtitle => _localizedValues['backupAndRestoreSubtitle']!;
  // Home screen
  String get recommendedChannels => _localizedValues['recommendedChannels']!;
  String get watchHistory => _localizedValues['watchHistory']!;
  String get myFavorites => _localizedValues['myFavorites']!;
  String get continueWatching => _localizedValues['continueWatching']!;
  String get channelStats => _localizedValues['channelStats']!;
  String get noPlaylistYet => _localizedValues['noPlaylistYet']!;
  String get addM3uToStart => _localizedValues['addM3uToStart']!;
  String get search => _localizedValues['search']!;

  // Player hints
  String get playerHintTV => _localizedValues['playerHintTV']!;
  String get playerHintDesktop => _localizedValues['playerHintDesktop']!;

  // More UI strings
  String get more => _localizedValues['more']!;
  String get close => _localizedValues['close']!;
  String get startingServer => _localizedValues['startingServer']!;
  String get selectM3uFile => _localizedValues['selectM3uFile']!;
  String get noFileSelected => _localizedValues['noFileSelected']!;
  String get epgAutoApplied => _localizedValues['epgAutoApplied']!;
  String get addFirstPlaylistTV => _localizedValues['addFirstPlaylistTV']!;
  String get addPlaylistSubtitle => _localizedValues['addPlaylistSubtitle']!;
  String get importFromUsb => _localizedValues['importFromUsb']!;
  String get scanQrToImport => _localizedValues['scanQrToImport']!;
  String get playlistUrlHint => _localizedValues['playlistUrlHint']!;
  String get qrStep1 => _localizedValues['qrStep1']!;
  String get qrStep2 => _localizedValues['qrStep2']!;
  String get qrStep3 => _localizedValues['qrStep3']!;
  String get qrSearchStep1 => _localizedValues['qrSearchStep1']!;
  String get qrSearchStep2 => _localizedValues['qrSearchStep2']!;
  String get qrSearchStep3 => _localizedValues['qrSearchStep3']!;
  String get scanToSearch => _localizedValues['scanToSearch']!;

  // Player gestures and EPG
  String get nextChannel => _localizedValues['nextChannel']!;
  String get previousChannel => _localizedValues['previousChannel']!;
  String get source => _localizedValues['source']!;
  String get nowPlaying => _localizedValues['nowPlaying']!;
  String get endsInMinutes => _localizedValues['endsInMinutes']!;
  String get upNext => _localizedValues['upNext']!;

  // Update dialog
  String get newVersionAvailable => _localizedValues['newVersionAvailable']!;
  String get whatsNew => _localizedValues['whatsNew']!;
  String get updateLater => _localizedValues['updateLater']!;
  String get updateNow => _localizedValues['updateNow']!;
  String get noReleaseNotes => _localizedValues['noReleaseNotes']!;

  // Settings messages
  String get autoPlayEnabled => _localizedValues['autoPlayEnabled']!;
  String get autoPlayDisabled => _localizedValues['autoPlayDisabled']!;
  String get bufferStrength => _localizedValues['bufferStrength']!;
  String get showFps => _localizedValues['showFps']!;
  String get showFpsSubtitle => _localizedValues['showFpsSubtitle']!;
  String get fpsEnabled => _localizedValues['fpsEnabled']!;
  String get fpsDisabled => _localizedValues['fpsDisabled']!;
  String get showClock => _localizedValues['showClock']!;
  String get showClockSubtitle => _localizedValues['showClockSubtitle']!;
  String get clockEnabled => _localizedValues['clockEnabled']!;
  String get clockDisabled => _localizedValues['clockDisabled']!;
  String get showNetworkSpeed => _localizedValues['showNetworkSpeed']!;
  String get showNetworkSpeedSubtitle =>
      _localizedValues['showNetworkSpeedSubtitle']!;
  String get networkSpeedEnabled => _localizedValues['networkSpeedEnabled']!;
  String get networkSpeedDisabled => _localizedValues['networkSpeedDisabled']!;
  String get showVideoInfo => _localizedValues['showVideoInfo']!;
  String get showVideoInfoSubtitle =>
      _localizedValues['showVideoInfoSubtitle']!;
  String get videoInfoEnabled => _localizedValues['videoInfoEnabled']!;
  String get videoInfoDisabled => _localizedValues['videoInfoDisabled']!;
  String get enableMultiScreen => _localizedValues['enableMultiScreen']!;
  String get enableMultiScreenSubtitle =>
      _localizedValues['enableMultiScreenSubtitle']!;
  String get multiScreenEnabled => _localizedValues['multiScreenEnabled']!;
  String get multiScreenDisabled => _localizedValues['multiScreenDisabled']!;
  String get showMultiScreenChannelName =>
      _localizedValues['showMultiScreenChannelName']!;
  String get showMultiScreenChannelNameSubtitle =>
      _localizedValues['showMultiScreenChannelNameSubtitle']!;
  String get multiScreenChannelNameEnabled =>
      _localizedValues['multiScreenChannelNameEnabled']!;
  String get multiScreenChannelNameDisabled =>
      _localizedValues['multiScreenChannelNameDisabled']!;
  String get defaultScreenPosition =>
      _localizedValues['defaultScreenPosition']!;
  String get screenPosition1 => _localizedValues['screenPosition1']!;
  String get screenPosition2 => _localizedValues['screenPosition2']!;
  String get screenPosition3 => _localizedValues['screenPosition3']!;
  String get screenPosition4 => _localizedValues['screenPosition4']!;
  String get screenPositionDesc => _localizedValues['screenPositionDesc']!;
  String get screenPositionSet => _localizedValues['screenPositionSet']!;
  String get multiScreenMode => _localizedValues['multiScreenMode']!;
  String get notImplemented => _localizedValues['notImplemented']!;
  String get volumeNormalizationNotImplemented =>
      _localizedValues['volumeNormalizationNotImplemented']!;
  String get autoRefreshNotImplemented =>
      _localizedValues['autoRefreshNotImplemented']!;
  String get rememberLastChannelEnabled =>
      _localizedValues['rememberLastChannelEnabled']!;
  String get rememberLastChannelDisabled =>
      _localizedValues['rememberLastChannelDisabled']!;
  String get epgEnabledAndLoaded => _localizedValues['epgEnabledAndLoaded']!;
  String get epgEnabledButFailed => _localizedValues['epgEnabledButFailed']!;
  String get epgEnabledPleaseConfigure =>
      _localizedValues['epgEnabledPleaseConfigure']!;
  String get epgDisabled => _localizedValues['epgDisabled']!;
  String get weak => _localizedValues['weak']!;
  String get medium => _localizedValues['medium']!;
  String get strong => _localizedValues['strong']!;

  // Errors
  String get errorTimeout => _localizedValues['errorTimeout']!;
  String get errorNetwork => _localizedValues['errorNetwork']!;
  String get usingCachedSource => _localizedValues['usingCachedSource']!;

  // Multi-screen player strings
  String get backToPlayer => _localizedValues['backToPlayer']!;
  String get miniMode => _localizedValues['miniMode']!;
  String get exitMultiScreen => _localizedValues['exitMultiScreen']!;
  String get screenNumber => _localizedValues['screenNumber']!;
  String get clickToAddChannel => _localizedValues['clickToAddChannel']!;
  String get selectChannel => _localizedValues['selectChannel']!;

  // Channel test and update strings
  String get collapse => _localizedValues['collapse']!;
  String get channelCountLabel => _localizedValues['channelCountLabel']!;
  String get showOnlyFailed => _localizedValues['showOnlyFailed']!;
  String get moveToUnavailable => _localizedValues['moveToUnavailable']!;
  String get stopTest => _localizedValues['stopTest']!;
  String get startTest => _localizedValues['startTest']!;
  String get complete => _localizedValues['complete']!;
  String get runInBackground => _localizedValues['runInBackground']!;
  String get movedToUnavailable => _localizedValues['movedToUnavailable']!;
  String get checkingUpdate => _localizedValues['checkingUpdate']!;
  String get alreadyLatestVersion => _localizedValues['alreadyLatestVersion']!;
  String get checkUpdateFailed => _localizedValues['checkUpdateFailed']!;
  String get updateFailed => _localizedValues['updateFailed']!;
  String get downloadUpdate => _localizedValues['downloadUpdate']!;
  String get downloadFailed => _localizedValues['downloadFailed']!;
  String get downloadComplete => _localizedValues['downloadComplete']!;
  String get runInstallerNow => _localizedValues['runInstallerNow']!;
  String get later => _localizedValues['later']!;
  String get installNow => _localizedValues['installNow']!;
  String get deletedChannels => _localizedValues['deletedChannels']!;
  String get testing => _localizedValues['testing']!;
  String get channelAvailableRestored =>
      _localizedValues['channelAvailableRestored']!;
  String get testingInBackground => _localizedValues['testingInBackground']!;
  String get restoredToCategory => _localizedValues['restoredToCategory']!;
  String get dlnaCast => _localizedValues['dlnaCast']!;

  // More settings messages
  String get dlnaCasting => _localizedValues['dlnaCasting']!;
  String get enableDlnaService => _localizedValues['enableDlnaService']!;
  String get dlnaServiceStarted => _localizedValues['dlnaServiceStarted']!;
  String get allowOtherDevicesToCast =>
      _localizedValues['allowOtherDevicesToCast']!;
  String get dlnaServiceStartedMsg =>
      _localizedValues['dlnaServiceStartedMsg']!;
  String get dlnaServiceStoppedMsg =>
      _localizedValues['dlnaServiceStoppedMsg']!;
  String get dlnaServiceStartFailed =>
      _localizedValues['dlnaServiceStartFailed']!;
  String get parentalControlNotImplemented =>
      _localizedValues['parentalControlNotImplemented']!;
  String get changePinNotImplemented =>
      _localizedValues['changePinNotImplemented']!;
  String get decodingModeSet => _localizedValues['decodingModeSet']!;
  String get videoOutput => _localizedValues['videoOutput']!;
  String get videoOutputAuto => _localizedValues['videoOutputAuto']!;
  String get videoOutputLibmpv => _localizedValues['videoOutputLibmpv']!;
  String get videoOutputGpu => _localizedValues['videoOutputGpu']!;
  String get videoOutputAutoDesc => _localizedValues['videoOutputAutoDesc']!;
  String get videoOutputLibmpvDesc => _localizedValues['videoOutputLibmpvDesc']!;
  String get videoOutputGpuDesc => _localizedValues['videoOutputGpuDesc']!;
  String get videoOutputSet => _localizedValues['videoOutputSet']!;
  String get windowsHwdecMode => _localizedValues['windowsHwdecMode']!;
  String get windowsHwdecModeSet => _localizedValues['windowsHwdecModeSet']!;
  String get windowsHwdecAutoSafe => _localizedValues['windowsHwdecAutoSafe']!;
  String get windowsHwdecAutoCopy => _localizedValues['windowsHwdecAutoCopy']!;
  String get windowsHwdecD3d11va => _localizedValues['windowsHwdecD3d11va']!;
  String get windowsHwdecDxva2 => _localizedValues['windowsHwdecDxva2']!;

  // d3d11vpp 去交错参数（仅 auto-safe 生效）
  String get d3d11vppMode => _localizedValues['d3d11vppMode']!;
  String get d3d11vppModeDesc => _localizedValues['d3d11vppModeDesc']!;
  String get d3d11vppOff => _localizedValues['d3d11vppOff']!;
  String get d3d11vppBob => _localizedValues['d3d11vppBob']!;
  String get d3d11vppAdaptive => _localizedValues['d3d11vppAdaptive']!;
  String get d3d11vppMocomp => _localizedValues['d3d11vppMocomp']!;

  String get windowsHwdecAutoSafeDesc =>
      _localizedValues['windowsHwdecAutoSafeDesc']!;
  String get windowsHwdecAutoCopyDesc =>
      _localizedValues['windowsHwdecAutoCopyDesc']!;
  String get windowsHwdecD3d11vaDesc =>
      _localizedValues['windowsHwdecD3d11vaDesc']!;
  String get windowsHwdecDxva2Desc =>
      _localizedValues['windowsHwdecDxva2Desc']!;
  String get allowSoftwareFallback =>
      _localizedValues['allowSoftwareFallback']!;
  String get allowSoftwareFallbackDesc =>
      _localizedValues['allowSoftwareFallbackDesc']!;
  String get allowSoftwareFallbackEnabled =>
      _localizedValues['allowSoftwareFallbackEnabled']!;
  String get allowSoftwareFallbackDisabled =>
      _localizedValues['allowSoftwareFallbackDisabled']!;
  String get fastBuffer => _localizedValues['fastBuffer']!;
  String get balancedBuffer => _localizedValues['balancedBuffer']!;
  String get stableBuffer => _localizedValues['stableBuffer']!;

  // Developer and debug settings
  String get developerAndDebug => _localizedValues['developerAndDebug']!;
  String get logLevel => _localizedValues['logLevel']!;
  String get logLevelSubtitle => _localizedValues['logLevelSubtitle']!;
  String get logLevelDebug => _localizedValues['logLevelDebug']!;
  String get logLevelRelease => _localizedValues['logLevelRelease']!;
  String get logLevelOff => _localizedValues['logLevelOff']!;
  String get logLevelDebugDesc => _localizedValues['logLevelDebugDesc']!;
  String get logLevelReleaseDesc => _localizedValues['logLevelReleaseDesc']!;
  String get logLevelOffDesc => _localizedValues['logLevelOffDesc']!;
  String get exportLogs => _localizedValues['exportLogs']!;
  String get exportLogsSubtitle => _localizedValues['exportLogsSubtitle']!;
  String get clearLogs => _localizedValues['clearLogs']!;
  String get clearLogsSubtitle => _localizedValues['clearLogsSubtitle']!;
  String get logFileLocation => _localizedValues['logFileLocation']!;
  String get logsCleared => _localizedValues['logsCleared']!;
  String get clearLogsConfirm => _localizedValues['clearLogsConfirm']!;
  String get clearLogsConfirmMessage =>
      _localizedValues['clearLogsConfirmMessage']!;
  String get webLogEnabledTitle => _localizedValues['webLogEnabledTitle']!;
  String get webLogEnabledSubtitleOn =>
      _localizedValues['webLogEnabledSubtitleOn']!;
  String get webLogEnabledSubtitleOff =>
      _localizedValues['webLogEnabledSubtitleOff']!;
  String get webLogEnabledMsg => _localizedValues['webLogEnabledMsg']!;
  String get bufferSizeNotImplemented =>
      _localizedValues['bufferSizeNotImplemented']!;
  String get volumeBoostSet => _localizedValues['volumeBoostSet']!;
  String get noBoostValue => _localizedValues['noBoostValue']!;
  String get epgUrlSavedAndLoaded => _localizedValues['epgUrlSavedAndLoaded']!;
  String get epgUrlSavedButFailed => _localizedValues['epgUrlSavedButFailed']!;
  String get epgUrlCleared => _localizedValues['epgUrlCleared']!;
  String get epgUrlSaved => _localizedValues['epgUrlSaved']!;
  String get pinNotImplemented => _localizedValues['pinNotImplemented']!;
  String get enter4DigitPin => _localizedValues['enter4DigitPin']!;
  String get allSettingsReset => _localizedValues['allSettingsReset']!;
  String get languageSwitchedToChinese =>
      _localizedValues['languageSwitchedToChinese']!;
  String get languageSwitchedToEnglish =>
      _localizedValues['languageSwitchedToEnglish']!;
  String get themeChangedMessage => _localizedValues['themeChangedMessage']!;
  String get defaultVersion => _localizedValues['defaultVersion']!;

  // Color scheme strings
  String get colorScheme => _localizedValues['colorScheme']!;
  String get selectColorScheme => _localizedValues['selectColorScheme']!;
  String get colorSchemeLotus => _localizedValues['colorSchemeLotus']!;
  String get colorSchemeOcean => _localizedValues['colorSchemeOcean']!;
  String get colorSchemeForest => _localizedValues['colorSchemeForest']!;
  String get colorSchemeSunset => _localizedValues['colorSchemeSunset']!;
  String get colorSchemeLavender => _localizedValues['colorSchemeLavender']!;
  String get colorSchemeMidnight => _localizedValues['colorSchemeMidnight']!;
  String get colorSchemeLotusLight =>
      _localizedValues['colorSchemeLotusLight']!;
  String get colorSchemeSky => _localizedValues['colorSchemeSky']!;
  String get colorSchemeSpring => _localizedValues['colorSchemeSpring']!;
  String get colorSchemeCoral => _localizedValues['colorSchemeCoral']!;
  String get colorSchemeViolet => _localizedValues['colorSchemeViolet']!;
  String get colorSchemeClassic => _localizedValues['colorSchemeClassic']!;
  String get colorSchemeDescLotus => _localizedValues['colorSchemeDescLotus']!;
  String get colorSchemeDescOcean => _localizedValues['colorSchemeDescOcean']!;
  String get colorSchemeDescForest =>
      _localizedValues['colorSchemeDescForest']!;
  String get colorSchemeDescSunset =>
      _localizedValues['colorSchemeDescSunset']!;
  String get colorSchemeDescLavender =>
      _localizedValues['colorSchemeDescLavender']!;
  String get colorSchemeDescMidnight =>
      _localizedValues['colorSchemeDescMidnight']!;
  String get colorSchemeDescLotusLight =>
      _localizedValues['colorSchemeDescLotusLight']!;
  String get colorSchemeDescSky => _localizedValues['colorSchemeDescSky']!;
  String get colorSchemeDescSpring =>
      _localizedValues['colorSchemeDescSpring']!;
  String get colorSchemeDescCoral => _localizedValues['colorSchemeDescCoral']!;
  String get colorSchemeDescViolet =>
      _localizedValues['colorSchemeDescViolet']!;
  String get colorSchemeDescClassic =>
      _localizedValues['colorSchemeDescClassic']!;
  String get colorSchemeChanged => _localizedValues['colorSchemeChanged']!;
  String get customColorPicker => _localizedValues['customColorPicker']!;
  String get selectedColor => _localizedValues['selectedColor']!;
  String get apply => _localizedValues['apply']!;
  String get customColorApplied => _localizedValues['customColorApplied']!;
  String get colorSchemeCustom => _localizedValues['colorSchemeCustom']!;

  // Local server web page strings
  String get importPlaylistTitle => _localizedValues['importPlaylistTitle']!;
  String get importPlaylistSubtitle =>
      _localizedValues['importPlaylistSubtitle']!;
  String get importFromUrlTitle => _localizedValues['importFromUrlTitle']!;
  String get importFromFileTitle => _localizedValues['importFromFileTitle']!;
  String get playlistNameOptional => _localizedValues['playlistNameOptional']!;
  String get enterPlaylistUrl => _localizedValues['enterPlaylistUrl']!;
  String get importUrlButton => _localizedValues['importUrlButton']!;
  String get selectFile => _localizedValues['selectFile']!;
  String get fileNameOptional => _localizedValues['fileNameOptional']!;
  String get fileUploadButton => _localizedValues['fileUploadButton']!;
  String get or => _localizedValues['or']!;
  String get pleaseEnterUrl => _localizedValues['pleaseEnterUrl']!;
  String get sentToTV => _localizedValues['sentToTV']!;
  String get sendFailed => _localizedValues['sendFailed']!;
  String get networkError => _localizedValues['networkError']!;

  // Simple menu
  String get simpleMenu => _localizedValues['simpleMenu']!;
  String get simpleMenuSubtitle => _localizedValues['simpleMenuSubtitle']!;
  String get simpleMenuEnabled => _localizedValues['simpleMenuEnabled']!;
  String get simpleMenuDisabled => _localizedValues['simpleMenuDisabled']!;

  // Progress bar mode
  String get progressBarMode => _localizedValues['progressBarMode']!;
  String get progressBarModeSubtitle =>
      _localizedValues['progressBarModeSubtitle']!;
  String get progressBarModeAuto => _localizedValues['progressBarModeAuto']!;
  String get progressBarModeAlways =>
      _localizedValues['progressBarModeAlways']!;
  String get progressBarModeNever => _localizedValues['progressBarModeNever']!;
  String get progressBarModeAutoDesc =>
      _localizedValues['progressBarModeAutoDesc']!;
  String get progressBarModeAlwaysDesc =>
      _localizedValues['progressBarModeAlwaysDesc']!;
  String get progressBarModeNeverDesc =>
      _localizedValues['progressBarModeNeverDesc']!;
  String get progressBarModeSet => _localizedValues['progressBarModeSet']!;

  // Seek step settings
  String get seekStepSeconds => _localizedValues['seekStepSeconds']!;
  String get seekStepSecondsSubtitle => _localizedValues['seekStepSecondsSubtitle']!;
  String get seekStep5s => _localizedValues['seekStep5s']!;
  String get seekStep10s => _localizedValues['seekStep10s']!;
  String get seekStep30s => _localizedValues['seekStep30s']!;
  String get seekStep60s => _localizedValues['seekStep60s']!;
  String get seekStep120s => _localizedValues['seekStep120s']!;
  String get seekStepSet => _localizedValues['seekStepSet']!;

  // Home display settings
  String get showWatchHistoryOnHome => _localizedValues['showWatchHistoryOnHome']!;
  String get showWatchHistoryOnHomeSubtitle => _localizedValues['showWatchHistoryOnHomeSubtitle']!;
  String get showFavoritesOnHome => _localizedValues['showFavoritesOnHome']!;
  String get showFavoritesOnHomeSubtitle => _localizedValues['showFavoritesOnHomeSubtitle']!;
  String get watchHistoryOnHomeEnabled => _localizedValues['watchHistoryOnHomeEnabled']!;
  String get watchHistoryOnHomeDisabled => _localizedValues['watchHistoryOnHomeDisabled']!;

  // Page transition animation settings
  String get pageTransitionAnimation => _localizedValues['pageTransitionAnimation']!;
  String get pageTransitionAnimationSubtitle => _localizedValues['pageTransitionAnimationSubtitle']!;
  String get transitionFade => _localizedValues['transitionFade']!;
  String get transitionSlide => _localizedValues['transitionSlide']!;
  String get transitionScale => _localizedValues['transitionScale']!;
  String get transitionNone => _localizedValues['transitionNone']!;
  String get transitionMaterial => _localizedValues['transitionMaterial']!;
  String get transitionCupertino => _localizedValues['transitionCupertino']!;
  String get transitionFadeDesc => _localizedValues['transitionFadeDesc']!;
  String get transitionSlideDesc => _localizedValues['transitionSlideDesc']!;
  String get transitionScaleDesc => _localizedValues['transitionScaleDesc']!;
  String get transitionNoneDesc => _localizedValues['transitionNoneDesc']!;
  String get transitionMaterialDesc => _localizedValues['transitionMaterialDesc']!;
  String get transitionCupertinoDesc => _localizedValues['transitionCupertinoDesc']!;
  String get pageTransitionSet => _localizedValues['pageTransitionSet']!;
  String get favoritesOnHomeEnabled => _localizedValues['favoritesOnHomeEnabled']!;
  String get favoritesOnHomeDisabled => _localizedValues['favoritesOnHomeDisabled']!;
  String get channelSnapshotPreview => _localizedValues['channelSnapshotPreview']!;
  String get channelSnapshotPreviewSubtitle => _localizedValues['channelSnapshotPreviewSubtitle']!;
  String get channelSnapshotPreviewEnabled => _localizedValues['channelSnapshotPreviewEnabled']!;
  String get channelSnapshotPreviewDisabled => _localizedValues['channelSnapshotPreviewDisabled']!;

  // 去交错（反隔行）设置
  String get deinterlace => _localizedValues['deinterlace']!;
  String get deinterlaceDesc => _localizedValues['deinterlaceDesc']!;
  String get deinterlaceEnabled => _localizedValues['deinterlaceEnabled']!;
  String get deinterlaceDisabled => _localizedValues['deinterlaceDisabled']!;

  // 存储与缓存设置
  String get storageCache => _localizedValues['storageCache']!;
  String get logoCache => _localizedValues['logoCache']!;
  String get logoCacheDesc => _localizedValues['logoCacheDesc']!;
  String get logoCacheEnabled => _localizedValues['logoCacheEnabled']!;
  String get logoCacheDisabled => _localizedValues['logoCacheDisabled']!;
  String get logoCacheDays => _localizedValues['logoCacheDays']!;
  String get logoCacheMaxObjects => _localizedValues['logoCacheMaxObjects']!;
  String get logoCacheUsage => _localizedValues['logoCacheUsage']!;
  String get clearLogoCache => _localizedValues['clearLogoCache']!;
  String get clearLogoCacheDesc => _localizedValues['clearLogoCacheDesc']!;
  String get clearLogoCacheConfirmTitle => _localizedValues['clearLogoCacheConfirmTitle']!;
  String get clearLogoCacheConfirmDesc => _localizedValues['clearLogoCacheConfirmDesc']!;
  String get logoCacheCleared => _localizedValues['logoCacheCleared']!;
  String get logoCacheClearFailed => _localizedValues['logoCacheClearFailed']!;
  String get logoCacheDaysHint1 => _localizedValues['logoCacheDaysHint1']!;
  String get logoCacheDaysHint3 => _localizedValues['logoCacheDaysHint3']!;
  String get logoCacheDaysHint7 => _localizedValues['logoCacheDaysHint7']!;
  String get logoCacheDaysHint14 => _localizedValues['logoCacheDaysHint14']!;
  String get logoCacheDaysHint30 => _localizedValues['logoCacheDaysHint30']!;
  String get logoCacheDaysHint60 => _localizedValues['logoCacheDaysHint60']!;
  String get logoCacheDaysHint90 => _localizedValues['logoCacheDaysHint90']!;
  String get logoCacheHintSmall => _localizedValues['logoCacheHintSmall']!;
  String get logoCacheHintBalanced => _localizedValues['logoCacheHintBalanced']!;
  String get logoCacheHintLarge => _localizedValues['logoCacheHintLarge']!;
  String get logoCacheHintXLarge => _localizedValues['logoCacheHintXLarge']!;
  String get logoCacheHintMax => _localizedValues['logoCacheHintMax']!;
  String get logoCacheDaysNever => _localizedValues['logoCacheDaysNever']!;
  String get items => _localizedValues['items']!;
  String get size => _localizedValues['size']!;
  String get calculating => _localizedValues['calculating']!;
  String get clear => _localizedValues['clear']!;

  // Map access for dynamic keys if needed
  String operator [](String key) => _localizedValues[key] ?? key;
}

class _AppStringsDelegate extends LocalizationsDelegate<AppStrings> {
  const _AppStringsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'zh'].contains(locale.languageCode);

  @override
  Future<AppStrings> load(Locale locale) {
    return SynchronousFuture<AppStrings>(
        AppStrings(locale, _getValues(locale)));
  }

  @override
  bool shouldReload(_AppStringsDelegate old) => false;

  Map<String, String> _getValues(Locale locale) {
    if (locale.languageCode == 'zh') {
      return _zhValues;
    } else {
      return _enValues;
    }
  }

}
