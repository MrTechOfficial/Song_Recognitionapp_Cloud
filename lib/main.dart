import 'dart:async';
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';




const String recztRecognitionBackendUrl =
    'https://song-recognitionapp-cloud.onrender.com/recognize';

/// Native iOS bridge that schedules file-based background uploads. The
/// operating system can continue these transfers while Reczt is suspended and
/// automatically waits for connectivity to return.
const MethodChannel _recztOfflineQueueChannel =
    MethodChannel('reczt/offline_queue');

// --------------------------------------------------------------------
// 🔗 SHARED APP CONSTANTS & HELPERS
// --------------------------------------------------------------------

/// Single source of truth for the Reczt App Store link. Previously this
/// was redeclared locally in several functions — consolidated here.
const String reczAppStoreUrl = "https://apps.apple.com/app/id6809193545";

// --------------------------------------------------------------------
// ⚖️ LEGAL & PRIVACY
// --------------------------------------------------------------------

// Increment this string whenever the Privacy Policy or Terms change
// materially. Reczt will then show the legal notice one more time.
const String recztLegalNoticeVersion = '2026-09-01-v2';

// Increment this string when the first-run User Manual changes materially.
const String recztUserManualVersion = '2026-09-07-v1';

// After the two HTML files are published on a permanent public website,
// paste their live URLs here. Until then, Reczt always shows the complete
// built-in copies below, so the in-app legal section is never a broken link.
const String recztPrivacyPolicyUrl = 'https://mrtechofficial.github.io/Song_Recognitionapp_Cloud/privacy.html';
const String recztTermsOfUseUrl = 'https://mrtechofficial.github.io/Song_Recognitionapp_Cloud/terms.html';

const String _recztPrivacyPolicyText = r'''Reczt Privacy Policy

Effective Date: September 1, 2026

Reczt (“Reczt,” “we,” “us,” or “our”) is operated by Leslie Kane. This Privacy Policy explains how Reczt handles information when you use the Reczt mobile application and related song-recognition services.

If you have questions about this Privacy Policy, contact us at georgethomasbazos@gmail.com.

1. Summary

Reczt is a general-audience song-recognition app. Reczt does not require a Reczt account. Reczt is free to use and does not contain advertising, subscriptions, or in-app purchases.

Reczt does not sell personal information, does not use personal information for targeted advertising, and does not track users across other companies’ apps or websites for advertising purposes.

Reczt processes limited information needed to recognize songs and provide app features. Some information stays only on your device, while some information is transmitted to service providers to perform song recognition or related functions.

2. Information Reczt Processes

A. Singing and Audio Recordings

When you choose to identify a song, Reczt records audio from your microphone.

When you are online, the recording is transmitted to Reczt’s recognition backend for the purpose of identifying the song. The backend creates temporary audio files while the recognition request is being processed. Those temporary files are designed to be deleted when the request ends.

When you make a recording while offline, Reczt first stores the queued recording locally on your device. On iOS, Reczt may schedule a system-managed background upload. The operating system can wait for connectivity and upload the queued recording after an internet connection becomes available, even while Reczt is not in the foreground. Once the upload reaches Reczt’s backend, the server performs the recognition work. Reczt does not intentionally maintain a permanent server-side library of queued recordings. The uploaded audio is held only in temporary processing files for the recognition request and is designed to be deleted when that request ends.

If an offline recording is successfully recognized, Reczt may keep a copy of your singing clip locally on your device as part of your Reczt history so you can replay it later. Local clips remain on your device until you delete the relevant history item, clear Reczt data, or remove the app.

B. Offline-Result Notifications

If you allow notifications, Reczt may ask iOS to display a local notification when a queued offline recording finishes processing successfully. The notification may contain the recognized song title and artist so the result is useful without opening the app.

This notification is scheduled on the device after the background upload receives the recognition response. Reczt does not need to send a push-notification device token to its backend for this feature. You can control Reczt notification permissions in iOS Settings.

C. Song Recognition and Transcription

Reczt may send audio to third-party service providers to identify the song:

- ACRCloud receives audio for audio or humming recognition. ACRCloud states in its terms that uploaded audio or video files are removed after fingerprints are generated, although fingerprints and related metadata may be handled under ACRCloud’s own terms and policies.
- Groq may receive audio when Reczt uses speech-to-text as a fallback recognition method. Reczt’s Groq organization is configured with Global Zero Data Retention (ZDR). Under Groq’s current ZDR documentation, customer inputs and outputs are not retained for system-reliability or abuse-monitoring purposes. Groq may still retain non-content usage metadata that does not contain customer inputs or outputs.
- Genius may receive short lyric-search queries derived from a transcription in order to identify possible songs.

Reczt does not intentionally write the content of Groq transcriptions or users’ raw recordings into its own production application logs.

D. Song and Music-Service Information

Reczt may send song titles and artist names to Spotify and Apple services to find canonical song information, links, artwork, genres, or other music metadata.

If you choose to create a Spotify playlist from Reczt history, Reczt uses Spotify’s authorization process to request the permissions needed to create or modify playlists. Reczt does not receive or store your Spotify password. In the current app, the Spotify access token used for playlist creation is used for that authorization session and is not intentionally stored as a persistent Reczt credential.

Your use of Spotify, Apple Music, and other third-party music services is also governed by those providers’ own terms and privacy policies.

E. Location and “Acoustic Memory”

If you grant location permission, Reczt may access your device location when you begin a singing session so the Acoustic Memory map can remember where you have used Reczt.

Acoustic Memory location information is stored locally on your device using compact approximate location buckets rather than maintaining a permanent server-side location history. Reczt’s current recognition requests do not send your Acoustic Memory latitude or longitude to Reczt’s recognition backend.

You can deny or revoke Reczt’s location permission through iOS Settings. Reczt’s core song-recognition feature can still function without the Acoustic Memory location feature.

F. Hands-Free Speech Recognition

If Auto Play is enabled and Reczt needs you to choose between two possible song matches, Reczt may ask you to say “first” or “second.”

This feature uses Apple’s Speech framework. Apple states that speech recognition performed with SFSpeechRecognizer may capture your voice audio and send it to Apple’s servers for processing. iOS asks for your permission before Reczt uses this feature.

G. Local App Data

Reczt stores certain information locally on your device so the app can function, including items such as:

- song-recognition history;
- locally saved singing clips;
- preferred music service and language;
- Auto Play and appearance preferences;
- local analytics such as song counts, artist counts, genre counts, emotion counts, and usage streaks;
- Acoustic Memory location usage; and
- pending offline recordings waiting for a system-managed upload and recognition.

History entries may include a local “Found Offline” flag so Reczt can show which results came from the offline queue.

This information is used to provide Reczt’s features and is not used for advertising.

H. Technical Information

Reczt and its hosting or network providers may process ordinary technical request information needed to deliver and protect the service, such as IP address, request timing, service status, device/network connectivity information, or error information.

Reczt does not use this information to create advertising profiles.

3. How Reczt Uses Information

Reczt uses information only as reasonably necessary to:

- recognize songs;
- process recordings that were queued while offline after connectivity returns;
- notify you on your device when an offline recording is successfully recognized;
- provide song links, artwork, genre information, and related metadata;
- create user-requested Spotify playlists;
- provide local history, analytics, Acoustic Memory, and offline-queue features;
- provide hands-free song-choice functionality;
- maintain, secure, troubleshoot, and improve the reliability of Reczt; and
- comply with applicable law.

4. Service Providers and Third Parties

Depending on the feature you use, information may be processed by service providers including:

- Render — backend hosting and infrastructure;
- ACRCloud — audio and humming recognition;
- Groq — fallback speech-to-text transcription;
- Genius — lyric-based song search;
- Spotify — music metadata, links, authorization, and playlist creation; and
- Apple — Apple Music/iTunes metadata, iOS permissions and local notifications, and Apple Speech Recognition.

These companies process information under their own agreements and privacy practices. Reczt uses these services only for app functionality and does not authorize them to use Reczt data for Reczt advertising.

5. Data Retention and Deletion

Reczt is designed to minimize server-side retention.

- Online and offline Reczt backend audio: temporary processing files are designed to be deleted when the recognition request ends.
- Offline queue before upload: the queued recording remains locally on your device until it is recognized, deleted, cleared, or the app is removed. The server does not receive the recording until a network upload actually begins.
- Groq: Reczt has enabled Global ZDR for customer inputs and outputs. Groq may retain non-content usage metadata as described in its documentation.
- ACRCloud: ACRCloud states that uploaded audio/video files are removed after fingerprint generation; its handling of fingerprints and related metadata is governed by its own terms.
- Local Reczt history and clips: remain on your device until you delete them or remove the app.
- Local preferences, analytics, Acoustic Memory information, and offline-result labels: generally remain on your device until the app or its local data is removed.

Reczt does not currently maintain a Reczt user account or a server-side user profile that requires a separate account-deletion process.

6. Your Choices

You control whether Reczt can use microphone, location, notifications, speech-recognition, Bluetooth, and Siri-related permissions through iOS.

You may:

- deny or revoke permissions in iOS Settings;
- delete individual saved song-history items;
- clear Reczt data and its associated local clips and queued recordings;
- revoke Spotify authorization through Spotify if you choose to do so; and
- delete Reczt from your device to remove Reczt’s locally stored app data, subject to any device backup settings controlled by Apple.

For privacy questions or requests concerning information Reczt may control, contact georgethomasbazos@gmail.com.

7. No Sale, Advertising, or Cross-App Tracking

Reczt does not sell personal information.

Reczt does not contain third-party advertising and does not use personal information for targeted or cross-context behavioral advertising.

8. Cookies

The native Reczt app does not use browser cookies for advertising or analytics. Third-party websites or authorization pages that you choose to open, including Spotify or Apple services, may use cookies or similar technologies under their own policies.

9. Children’s Privacy

Reczt is a general-audience service and is not directed to children under 13.

If you are under 13, you should not use Reczt. Users who are under the age of majority in their jurisdiction should use Reczt only with permission of a parent or legal guardian.

Reczt does not ask users to provide a date of birth and does not knowingly create profiles about children. If you believe a child under 13 has provided personal information to Reczt in a manner that should be deleted, contact georgethomasbazos@gmail.com.

10. International Processing

Some service providers used by Reczt may process information in the United States or other countries. Privacy laws may differ from those in your place of residence.

11. Security

Reczt uses reasonable technical and organizational measures intended to protect information. However, no internet transmission, device, or storage system can be guaranteed to be completely secure.

12. Changes to This Privacy Policy

We may update this Privacy Policy as Reczt changes. If we make a material change, we may provide notice in the app and update the Effective Date above.

13. Contact

Leslie Kane
Operator / Publisher of Reczt
Email: georgethomasbazos@gmail.com''';

const String _recztTermsOfUseText = r'''Reczt Terms of Use

Effective Date: September 1, 2026

These Terms of Use (“Terms”) govern your use of the Reczt mobile application and related services (“Reczt”). Reczt is operated by Leslie Kane (“we,” “us,” or “our”).

By using Reczt, or by tapping Agree & Continue when the Terms are presented in the app, you agree to these Terms. If you do not agree, do not use Reczt.

Questions about these Terms may be sent to georgethomasbazos@gmail.com.

1. Eligibility and General Audience

Reczt is a general-audience app and is not directed to children under 13.

You must be at least 13 years old to use Reczt. If you are under the age of majority where you live, you may use Reczt only with the permission and supervision of a parent or legal guardian who agrees to these Terms on your behalf.

Some third-party services available through Reczt, including Spotify, may impose their own minimum-age or account-eligibility requirements. You may use those features only if you are eligible under the applicable third-party terms.

2. What Reczt Does

Reczt is designed to help users identify songs by singing, humming, or recording audio and to provide links and related song information.

Reczt may also provide features such as:

- song history and locally saved singing clips;
- Spotify and Apple Music links;
- Spotify playlist creation when authorized by the user;
- local listening analytics and recommendations;
- Acoustic Memory location features;
- an offline recording queue that can upload recordings after connectivity returns;
- local notifications for successfully recognized offline recordings; and
- hands-free song-choice functionality.

Reczt is currently provided free of charge, with no subscriptions, in-app purchases, or advertisements.

3. License to Use Reczt

Subject to these Terms and any applicable Apple license terms, we grant you a limited, personal, non-exclusive, non-transferable, revocable license to use Reczt for lawful personal use.

You may not:

- copy, sell, rent, sublicense, or commercially exploit Reczt except as permitted by law;
- attempt to interfere with or overload Reczt’s servers or third-party services;
- use Reczt to violate another person’s intellectual-property, privacy, publicity, or other rights;
- use Reczt for unlawful, fraudulent, abusive, or harmful purposes;
- circumvent technical limitations, security measures, rate limits, or service restrictions; or
- reverse engineer or attempt to derive Reczt source code except to the extent such restriction is prohibited by applicable law.

4. Your Audio and Inputs

You retain any rights you may have in recordings of your own voice.

When you submit audio to Reczt, you authorize Reczt and its service providers to transmit, temporarily store, process, analyze, and transform that audio only as reasonably necessary to provide song recognition and related app functionality.

If you make a recording while offline, you also authorize Reczt to keep that recording locally on your device and to schedule a system-managed upload after connectivity becomes available. Once the upload reaches the backend, Reczt may process the recording even if the app is not in the foreground. Temporary backend audio files are designed to be deleted when the recognition request ends.

You should not use Reczt to submit passwords, financial information, health information, confidential conversations, or other sensitive information.

5. Offline Processing and Notifications

Offline processing depends on iOS background-transfer scheduling, internet connectivity, Reczt’s backend, and recognition providers. Delivery timing is not guaranteed.

If an offline recording is successfully recognized and you have allowed notifications, Reczt may ask iOS to display a local notification that includes the recognized song title and artist. You can control notification permissions in iOS Settings.

Force-quitting the app, device settings, operating-system resource decisions, network conditions, or third-party outages may delay or prevent a queued upload or notification.

6. Song Recognition Is Not Guaranteed

Song recognition is probabilistic and may be incorrect.

Reczt may return the wrong song, fail to identify a song, provide incomplete metadata, or offer more than one possible match. The hands-free “first or second” feature and the stricter rules used for unattended offline recognition are intended to reduce incorrect automatic results but do not guarantee accuracy.

You are responsible for confirming any result before relying on it.

7. Third-Party Music and Technology Services

Reczt relies on or links to third-party services, which may include ACRCloud, Groq, Genius, Spotify, Apple Music, iTunes/Apple services, Render, and Apple Speech Recognition.

Those services are operated by independent third parties and may be subject to their own terms, privacy policies, account requirements, availability, rate limits, geographic restrictions, or fees imposed by those third parties.

Reczt is not Spotify, Apple, ACRCloud, Groq, Genius, or Render, and use of those names does not imply ownership, sponsorship, or endorsement except where expressly stated.

If you authorize Reczt to create a Spotify playlist, you authorize Reczt to use the permissions displayed by Spotify for that purpose. You remain responsible for your Spotify account and for compliance with Spotify’s terms.

8. Music, Artwork, and Other Third-Party Content

Song names, artist names, album names, artwork, music-service branding, and other third-party content belong to their respective owners.

Reczt does not claim ownership of third-party music or artwork. Any third-party content displayed or linked through Reczt is provided for identification, navigation, or interoperability with the relevant music service.

9. Privacy

Your use of Reczt is subject to the Reczt Privacy Policy, which explains how audio, offline uploads, location, local app data, and third-party services are handled.

By using Reczt, you acknowledge the Privacy Policy and consent to permission-based processing where consent is required by the operating system or applicable law.

10. Apple Terms

If you obtain Reczt through Apple’s App Store, Apple’s applicable App Store terms and Apple’s standard Licensed Application End User License Agreement may also apply to your use of the app.

These Terms supplement, and do not replace, any mandatory rights or obligations that apply under Apple’s terms or applicable law.

11. Availability and Changes

We may modify, suspend, discontinue, or update Reczt or any feature at any time.

Third-party APIs and services can change without notice, and a feature that depends on a third party may stop working or operate differently.

We do not guarantee that Reczt will always be available, uninterrupted, secure, or error-free.

12. Disclaimer of Warranties

TO THE MAXIMUM EXTENT PERMITTED BY LAW, RECZT IS PROVIDED “AS IS” AND “AS AVAILABLE.”

WE DISCLAIM WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, NON-INFRINGEMENT, AND ANY WARRANTIES ARISING FROM COURSE OF DEALING OR USAGE OF TRADE, EXCEPT WHERE SUCH DISCLAIMERS ARE NOT PERMITTED BY LAW.

Nothing in these Terms limits rights that cannot legally be waived.

13. Limitation of Liability

TO THE MAXIMUM EXTENT PERMITTED BY LAW, LESLIE KANE AND RECZT WILL NOT BE LIABLE FOR INDIRECT, INCIDENTAL, SPECIAL, CONSEQUENTIAL, EXEMPLARY, OR PUNITIVE DAMAGES, OR FOR LOSS OF DATA, PROFITS, GOODWILL, OR USE, ARISING FROM OR RELATED TO RECZT OR THIRD-PARTY SERVICES.

TO THE EXTENT LIABILITY CANNOT BE EXCLUDED, OUR TOTAL LIABILITY ARISING OUT OF OR RELATING TO RECZT WILL NOT EXCEED THE GREATER OF (A) THE AMOUNT YOU PAID TO USE RECZT DURING THE 12 MONTHS BEFORE THE EVENT GIVING RISE TO THE CLAIM OR (B) US$50.

Because Reczt is currently free, the US$50 amount may apply where permitted by law.

Some jurisdictions do not allow certain exclusions or limitations, so parts of this section may not apply to you.

14. Your Responsibility for Lawful Use

You are responsible for your use of Reczt and for complying with applicable laws and third-party terms.

You agree not to intentionally misuse the service or submit material in a manner that violates another person’s rights.

15. Suspension or Termination

We may restrict or terminate access to Reczt if reasonably necessary to protect users, Reczt, third-party services, legal rights, or service security, or if these Terms are materially violated.

You may stop using Reczt at any time by deleting the app.

16. Governing Law

These Terms are governed by the laws of the State of New York, without regard to conflict-of-law principles, except where applicable consumer law requires otherwise.

Any dispute that is not subject to a mandatory alternative forum under applicable law may be brought in a court of competent jurisdiction in New York State.

17. Changes to These Terms

We may update these Terms when Reczt changes or when legal or third-party requirements change.

If a change is material, we may provide notice in the app and require you to review or accept the updated Terms before continuing to use Reczt.

18. Severability

If any provision of these Terms is found unenforceable, the remaining provisions will remain in effect to the extent permitted by law.

19. Entire Agreement

These Terms, the Reczt Privacy Policy, and applicable Apple license terms constitute the agreement governing your use of Reczt, except where other mandatory terms apply.

20. Contact

Leslie Kane
Operator / Publisher of Reczt
Email: georgethomasbazos@gmail.com''';



/// Native iOS channel used to share a true tappable Link Presentation card.
/// If the native iOS helper is not installed, sharing falls back to a normal
/// text + URL share so the feature still works on every platform.
const MethodChannel _recztRichShareChannel = MethodChannel('reczt/rich_share');

/// Native iOS bridge for hands-free candidate confirmation.
const MethodChannel _recztVoiceChoiceChannel = MethodChannel('reczt/voice_choice');

/// Native iOS MusicKit bridge used to create an Apple Music playlist from the
/// songs the user has checked on the History page.
const MethodChannel _recztAppleMusicChannel =
    MethodChannel('reczt/apple_music');

/// Native iOS StoreKit bridge used for Apple's system review prompt.
const MethodChannel _recztStoreReviewChannel =
    MethodChannel('reczt/store_review');

const String _recztReviewSuccessCountKey = 'reczt_review_success_count_v1';
const String _recztReviewLastRequestKey = 'reczt_review_last_request_ms_v1';
const int _recztReviewFirstPromptAt = 8;
const Duration _recztReviewRequestInterval = Duration(days: 30);

/// Captures a Flutter preview widget only for use as LPLinkMetadata artwork.
/// The PNG is NOT shared as an attachment; on iOS it becomes the image inside
/// the tappable rich-link card.
Future<String?> _captureRichSharePreview(
  GlobalKey previewKey,
  String fileName,
) async {
  try {
    final boundary =
        previewKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;

    final image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return null;

    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/$fileName');
    await file.writeAsBytes(byteData.buffer.asUint8List(), flush: true);
    return file.path;
  } catch (e) {
    debugPrint('Error preparing rich-share preview: $e');
    return null;
  }
}

Rect? _shareOriginForContext(BuildContext context) {
  try {
    final renderObject = context.findRenderObject();
    if (renderObject is RenderBox && renderObject.hasSize) {
      return renderObject.localToGlobal(Offset.zero) & renderObject.size;
    }
  } catch (_) {}
  return null;
}

/// Shares Reczt as an interactive rich link on iOS.
///
/// On iOS, the native helper presents UIActivityViewController with
/// LPLinkMetadata so Messages can display a polished, tappable card whose
/// destination is [reczAppStoreUrl]. On all other platforms (and as an iOS
/// safety fallback), this shares the same message plus the Reczt URL.
Future<void> shareRecztInteractiveCard({
  required BuildContext context,
  required String title,
  required String message,
  String? previewImagePath,
}) async {
  final uri = Uri.parse(reczAppStoreUrl);

  if (!kIsWeb && Platform.isIOS) {
    try {
      await _recztRichShareChannel.invokeMethod<void>('shareRichLink', {
        'title': title,
        'message': message,
        'url': uri.toString(),
        'previewImagePath': previewImagePath,
      });
      return;
    } on MissingPluginException {
      debugPrint(
        'Reczt rich-share iOS helper is not registered; using URL-share fallback.',
      );
    } on PlatformException catch (e) {
      debugPrint('Native rich-share failed (${e.code}); using fallback.');
    } catch (e) {
      debugPrint('Native rich-share failed: $e');
    }
  }

  final origin = _shareOriginForContext(context);
  await Share.share(
    '$message\n\n${uri.toString()}',
    subject: title,
    sharePositionOrigin: origin,
  );
}

/// Fetches the current device location for acoustic-map pin tracking.
///
/// The OS permission prompt is triggered the first time the microphone is used.
/// Medium accuracy is plenty for the world map and usually resolves much faster
/// than GPS-level accuracy. If a fresh fix is temporarily unavailable, Reczt
/// falls back to the device's last known position so a pin can still be placed.
Future<Position?> getCurrentDeviceLocation() async {
  try {
    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }
    if (permission == LocationPermission.deniedForever) return null;

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      ).timeout(const Duration(seconds: 5));
    } catch (_) {
      return await Geolocator.getLastKnownPosition();
    }
  } catch (e) {
    debugPrint('Error fetching device location: $e');
    return null;
  }
}

/// Lightweight metadata returned by the iTunes Search API.
/// Reczt uses this only as a catalog metadata fallback after recognition;
/// recognition itself still comes from your existing backend / ACRCloud pipeline.
bool _artistLooksMeaningful(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return false;

  // A real artist name can contain punctuation, numbers, accents, and any of
  // Reczt's supported writing systems. Reject only values that are effectively
  // made of separators, line-drawing glyphs, replacement characters, or other
  // catalog corruption.
  if (value == '!!!') return true; // Legitimate artist name.

  if (RegExp(r'[\u2500-\u259F\uFFFD]').hasMatch(value)) return false;

  final compact = value.replaceAll(RegExp(r'\s+'), '');
  if (compact.isEmpty) return false;

  final meaningful = RegExp(
    r'[A-Za-z0-9\u00C0-\u024F\u0370-\u052F\u0590-\u08FF\u0900-\u097F\u3040-\u30FF\u3400-\u9FFF\uAC00-\uD7AF]',
    unicode: true,
  ).allMatches(compact).length;

  final visibleCount = compact.runes.length;
  if (meaningful == 0) return false;
  if (visibleCount >= 4 && meaningful / visibleCount < 0.35) return false;

  final mojibakeMarkers = RegExp(r'[ÃÂÐÑ�]').allMatches(value).length;
  if (mojibakeMarkers >= 2) return false;

  return true;
}

String _sanitizeArtistName(String? raw) {
  var value = (raw ?? '')
      .replaceAll(
        RegExp(
          r'[\u0000-\u001F\u007F-\u009F\u200B\u200C\u200D\u2060\uFEFF]',
          unicode: true,
        ),
        ' ',
      )
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  value = value
      .replaceAll(RegExp(r'^[\s|=_~\-–—•·…]+'), '')
      .replaceAll(RegExp(r'[\s|=_~\-–—•·…]+$'), '')
      .trim();

  return _artistLooksMeaningful(value) ? value : '';
}

bool _isTraditionalSongTitle(String title) {
  final normalized = _catalogComparable(title);
  return normalized == 'happy birthday' ||
      normalized == 'happy birthday to you';
}

String _fallbackArtistForTitle(String title) =>
    _isTraditionalSongTitle(title) ? 'Traditional' : '';

class _SongLookupMetadata {
  final String? artworkUrl;
  final String? genre;
  final String? artist;

  const _SongLookupMetadata({
    this.artworkUrl,
    this.genre,
    this.artist,
  });
}

/// Keeps real catalog genres instead of collapsing anything unfamiliar into
/// "Other". A few equivalent labels are canonicalized so counts do not split
/// between spelling variants.
String _normalizeGenre(String? rawGenre) {
  final value = (rawGenre ?? '').trim();
  if (value.isEmpty) return '';

  final lower = value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  if (lower == 'other' ||
      lower == 'unknown' ||
      lower == 'unknown genre' ||
      lower == 'n/a') {
    return '';
  }

  if (lower.contains('hip-hop') ||
      lower.contains('hip hop') ||
      lower == 'rap' ||
      lower.contains('rap/hip')) {
    return 'hip-hop/rap';
  }
  if (lower.contains('r&b') ||
      lower.contains('rnb') ||
      lower.contains('rhythm and blues') ||
      lower == 'soul') {
    return 'r&b/soul';
  }
  if (lower.contains('singer/songwriter') ||
      lower.contains('singer-songwriter')) {
    return 'singer/songwriter';
  }
  if (lower.contains('alternative')) return 'alternative';
  if (lower.contains('indie')) return 'indie';
  if (lower.contains('electronic')) return 'electronic';
  if (lower.contains('dance')) return 'dance';
  if (lower.contains('country')) return 'country';
  if (lower.contains('latin')) return 'latin';
  if (lower.contains('metal')) return 'metal';
  if (lower.contains('folk')) return 'folk';
  if (lower.contains('blues')) return 'blues';
  if (lower.contains('jazz')) return 'jazz';
  if (lower.contains('classical')) return 'classical';
  if (lower.contains('reggae')) return 'reggae';
  if (lower.contains('soundtrack')) return 'soundtrack';
  if (lower.contains('world')) return 'world';
  if (lower.contains('k-pop') || lower.contains('kpop')) return 'k-pop';
  if (lower.contains('pop')) return 'pop';
  if (lower.contains('rock')) return 'rock';

  // Preserve a real catalog label even when it is not in Reczt's common list.
  return lower;
}

String _formatGenreLabel(String rawGenre) {
  final value = rawGenre.trim();
  if (value.isEmpty) return '';
  switch (value.toLowerCase()) {
    case 'hip-hop/rap':
      return 'Hip-Hop/Rap';
    case 'r&b/soul':
      return 'R&B/Soul';
    case 'singer/songwriter':
      return 'Singer/Songwriter';
    case 'k-pop':
      return 'K-Pop';
  }

  return value
      .split(RegExp(r'[\s/]+'))
      .where((part) => part.isNotEmpty)
      .map((part) =>
          part.length == 1 ? part.toUpperCase() : '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}

String _normalizeEmotion(String? rawEmotion) {
  final value = (rawEmotion ?? '').toLowerCase().trim();
  if (value.isEmpty) return '';
  if (value.contains('sad') ||
      value.contains('melanch') ||
      value.contains('blue') ||
      value.contains('sorrow')) {
    return 'sad';
  }
  if (value.contains('hype') ||
      value.contains('energetic') ||
      value.contains('excited') ||
      value.contains('party') ||
      value.contains('upbeat')) {
    return 'hype';
  }
  if (value.contains('romantic') ||
      value.contains('love') ||
      value.contains('tender')) {
    return 'romantic';
  }
  if (value.contains('happy') ||
      value.contains('joy') ||
      value.contains('positive') ||
      value.contains('bright')) {
    return 'happy';
  }
  return '';
}

/// Uses backend emotion when one is available. If the current backend response
/// does not include mood, Reczt applies a conservative title/genre fallback.
/// Sad words are intentionally checked before romantic words so a title such as
/// "Love Is Gone" is categorized as sad instead of defaulting to happy.
String _resolveSongEmotion({
  required String title,
  required String artist,
  String? backendEmotion,
  String? genre,
}) {
  final normalizedBackend = _normalizeEmotion(backendEmotion);
  if (normalizedBackend.isNotEmpty) return normalizedBackend;

  final text = '${title.toLowerCase()} ${artist.toLowerCase()}';

  const sadSignals = <String>[
    'gone',
    'goodbye',
    'lost',
    'lonely',
    'alone',
    'broken',
    'heartbreak',
    'tears',
    'cry',
    'crying',
    'hurt',
    'pain',
    'sorry',
    'miss you',
    'missing you',
    'without you',
    'empty',
    'death',
    'dying',
    'die',
    'never again',
  ];
  if (sadSignals.any(text.contains)) return 'sad';

  const hypeSignals = <String>[
    'party',
    'dance',
    'dancing',
    'turn up',
    'fire',
    'shake',
    'jump',
    'workout',
    'pump',
    'hype',
    'celebrate',
    'celebration',
  ];
  if (hypeSignals.any(text.contains)) return 'hype';

  const romanticSignals = <String>[
    'love',
    'lover',
    'heart',
    'kiss',
    'baby',
    'romance',
    'marry',
    'forever',
    'together',
  ];
  if (romanticSignals.any(text.contains)) return 'romantic';

  const happySignals = <String>[
    'happy',
    'smile',
    'sunshine',
    'good day',
    'beautiful day',
    'joy',
    'glad',
    'wonderful',
  ];
  if (happySignals.any(text.contains)) return 'happy';

  final normalizedGenre = _normalizeGenre(genre);
  if (normalizedGenre == 'blues') return 'sad';
  if (normalizedGenre == 'dance' || normalizedGenre == 'electronic') {
    return 'hype';
  }

  // The chart currently has four supported mood buckets. Happy is used only as
  // the final neutral fallback after all stronger evidence above is exhausted.
  return 'happy';
}

String _catalogComparable(String value) {
  return value
      .toLowerCase()
      .replaceAll(
        RegExp(
          r'[^a-z0-9\u00C0-\u024F\u0400-\u04FF\u3040-\u30FF\u3400-\u9FFF\uAC00-\uD7AF]+',
        ),
        ' ',
      )
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

double _catalogTextScore(String candidate, String target) {
  final a = _catalogComparable(candidate);
  final b = _catalogComparable(target);
  if (a.isEmpty || b.isEmpty) return 0;
  if (a == b) return 1;
  if (a.contains(b) || b.contains(a)) return 0.88;

  final aTokens = a.split(' ').where((e) => e.isNotEmpty).toSet();
  final bTokens = b.split(' ').where((e) => e.isNotEmpty).toSet();
  if (aTokens.isEmpty || bTokens.isEmpty) return 0;
  final intersection = aTokens.intersection(bTokens).length.toDouble();
  final union = aTokens.union(bTokens).length.toDouble();
  return union == 0 ? 0 : intersection / union;
}

Future<_SongLookupMetadata> fetchSongMetadataForSong(
  String title,
  String artist,
) async {
  try {
    final query = artist.trim().isEmpty ? title : '$title $artist';
    final encoded = Uri.encodeComponent(query);
    final url = Uri.parse(
      'https://itunes.apple.com/search?term=$encoded&entity=song&limit=8',
    );
    final response = await http.get(url).timeout(const Duration(seconds: 6));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final results = data['results'];
      if (results is List && results.isNotEmpty) {
        Map<String, dynamic>? best;
        double bestScore = -1;

        for (final raw in results.whereType<Map>()) {
          final item = Map<String, dynamic>.from(raw);
          final candidateTitle = (item['trackName'] ?? '').toString();
          final candidateArtist = (item['artistName'] ?? '').toString();
          final titleScore = _catalogTextScore(candidateTitle, title);
          final artistScore = artist.trim().isEmpty
              ? 1.0
              : _catalogTextScore(candidateArtist, artist);
          final score = artist.trim().isEmpty
              ? titleScore
              : (0.68 * titleScore) + (0.32 * artistScore);

          if (score > bestScore) {
            bestScore = score;
            best = item;
          }
        }

        if (best != null && bestScore >= 0.45) {
          final artwork = (best['artworkUrl100'] ?? '').toString();
          final rawGenre = best['primaryGenreName']?.toString();
          final normalizedGenre = _normalizeGenre(rawGenre);
          final catalogArtist =
              _sanitizeArtistName(best['artistName']?.toString());
          return _SongLookupMetadata(
            artworkUrl: artwork.isEmpty
                ? null
                : artwork.replaceAll('100x100bb', '600x600bb'),
            genre: normalizedGenre.isEmpty ? null : normalizedGenre,
            artist: catalogArtist.isEmpty ? null : catalogArtist,
          );
        }
      }
    }
  } catch (e) {
    debugPrint('Error fetching song metadata: $e');
  }
  return const _SongLookupMetadata();
}

/// Compatibility helper for older call sites that only have a combined query.
Future<_SongLookupMetadata> fetchSongMetadata(String query) async {
  return fetchSongMetadataForSong(query, '');
}

/// Kept as a compatibility helper for the existing QuickShare code.
Future<String?> fetchAlbumArtwork(String query) async {
  return (await fetchSongMetadata(query)).artworkUrl;
}

/// Compatibility wrappers retained so older call sites do not break.
String inferGenreFromTitle(String title) => '';
String refineEmotionFromTitle(String title, String backendEmotion) =>
    _resolveSongEmotion(
      title: title,
      artist: '',
      backendEmotion: backendEmotion,
    );



Future<void> _recordSuccessfulRecognitionAndMaybeRequestReview() async {
  final prefs = await SharedPreferences.getInstance();
  final successfulCount =
      (prefs.getInt(_recztReviewSuccessCountKey) ?? 0) + 1;
  await prefs.setInt(_recztReviewSuccessCountKey, successfulCount);

  if (successfulCount < _recztReviewFirstPromptAt) return;

  final now = DateTime.now();
  final lastRequestMs = prefs.getInt(_recztReviewLastRequestKey);
  if (lastRequestMs != null) {
    final lastRequest =
        DateTime.fromMillisecondsSinceEpoch(lastRequestMs);
    if (now.difference(lastRequest) < _recztReviewRequestInterval) {
      return;
    }
  }

  // Store the request time before invoking StoreKit. Apple intentionally
  // doesn't tell apps whether the review sheet actually appeared, so Reczt
  // throttles its own request attempts to once every 30 days.
  await prefs.setInt(
    _recztReviewLastRequestKey,
    now.millisecondsSinceEpoch,
  );

  if (kIsWeb || !Platform.isIOS) return;

  try {
    await _recztStoreReviewChannel.invokeMethod<void>('requestReview');
  } on MissingPluginException catch (e) {
    debugPrint('Reczt review bridge is unavailable: $e');
  } on PlatformException catch (e) {
    debugPrint('Reczt review request failed (${e.code}): ${e.message}');
  } catch (e) {
    debugPrint('Reczt review request failed: $e');
  }
}

// --------------------------------------------------------------------
// 🔔 LOCAL NOTIFICATIONS (offline-queue "song found" alert)
// --------------------------------------------------------------------
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();
Future<void>? _notificationInitializationFuture;

Future<void> ensureLocalNotificationsInitialized() {
  return _notificationInitializationFuture ??= initLocalNotifications();
}

Future<void> initLocalNotifications() async {
  const AndroidInitializationSettings androidInit =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  final DarwinInitializationSettings iosInit = DarwinInitializationSettings();
  final InitializationSettings initSettings = InitializationSettings(
    android: androidInit,
    iOS: iosInit,
    macOS: iosInit,
  );

  await flutterLocalNotificationsPlugin.initialize(settings: initSettings);

  // Android 13+ requires explicitly requesting notification permission.
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.requestNotificationsPermission();

  // iOS/macOS permission request.
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
      ?.requestPermissions(alert: true, badge: true, sound: true);
}

/// Fires the "Reczt has found your queued song!" notification once a
/// song recorded while offline is successfully matched after connectivity
/// is restored.
Future<void> showQueuedSongFoundNotification(String lang) async {
  await ensureLocalNotificationsInitialized();
  final String body =
      localizedStrings[lang]?['queued_song_found'] ?? localizedStrings['en']!['queued_song_found']!;
  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'reczt_offline_queue',
    'Offline Queue',
    channelDescription: 'Notifies you when a song recorded offline is found once you\'re back online.',
    importance: Importance.high,
    priority: Priority.high,
  );
  const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
  );
  const NotificationDetails details = NotificationDetails(
    android: androidDetails,
    iOS: iosDetails,
    macOS: iosDetails,
  );

  try {
    await flutterLocalNotificationsPlugin.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: 'Reczt',
      body: body,
      notificationDetails: details,
    );
  } catch (e) {
    debugPrint('Error showing queued-song notification: $e');
  }
}


// iOS offline recordings use a native background URLSession upload rather
// than BGProcessingTask. Background URLSession transfers are file-based and
// can wait for connectivity while the app is suspended.
//
// The recognition itself still happens on Reczt's backend. The native bridge
// stores successful server responses until Flutter can import them into normal
// history and analytics.

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final int? savedColorValue = prefs.getInt('theme_seed_color');
  final Color initialSeedColor =
      savedColorValue != null ? Color(savedColorValue) : Colors.deepPurple;
  final String initialLang = prefs.getString('preferred_language') ?? 'en';

  runApp(MyApp(currentLang: initialLang, seedColor: initialSeedColor));
  // Notification setup no longer blocks the first frame. Any queued-song
  // notification still awaits this same Future before it is shown.
  unawaited(ensureLocalNotificationsInitialized());
}

// --------------------------------------------------------------------
// 🌍 TRANSLATION DICTIONARY (UI LOCALIZATION)
// --------------------------------------------------------------------
final Map<String, Map<String, String>> localizedStrings = {
  'en': {
    "clear_this_data": 'Clear This Data?',
    "clear_this_data_confirm": 'Clear only the {section} data? Your other Reczt data will stay.',
    "data_box_cleared": 'This data box was cleared.',
    "emotions": 'Emotions',
    "cleared": 'Cleared',
    'clear_reczt_data': 'Clear Reczt Data',
    'clear_reczt_data_desc': 'Deletes saved history, singing clips, analytics, Acoustic Memory pins, and queued offline recordings from this device. App preferences are kept.',
    'clear_reczt_data_confirm': 'This will permanently delete your saved song history, singing clips, analytics, Acoustic Memory locations, and queued offline recordings from this device. Your language, music-app, theme, Auto Play, and legal preferences will be kept. This cannot be undone.',
    'clear_data_action': 'Clear Data',
    'clear_reczt_data_success': 'Reczt data was cleared from this device.',
    'clear_reczt_data_error': 'Reczt could not clear all local data. Please try again.',
    'legal_privacy': 'Legal & Privacy',
    'privacy_policy': 'Privacy Policy',
    'terms_of_use': 'Terms of Use',
    'open_source_licenses': 'Open-Source Licenses',
    'legal_notice_title': 'Welcome to Reczt',
    'legal_notice_body': 'Before using Reczt, please review the Privacy Policy and Terms of Use. By tapping Agree & Continue, you agree to the Terms and acknowledge the Privacy Policy.',
    'legal_accept': 'Agree & Continue',
    'legal_close': 'Close',
    'view_online': 'View Online',
    'app_title': 'Hands-Free Song Identifier',
    'where_are_you': 'Where Are You?',
    'quiet_room': 'A quiet room',
    'loud_room': 'A loud room with background noise',
    'initial_status': 'Select your environment and tap the mic or Say "Hey Siri, Activate Reczt"!',
    'listening': 'Listening...',
    'searching': 'Searching database...',
    'enhanced_search': "Still searching — using enhanced recognition…",
    'location_pin_permission': "Allow location access to place Acoustic Memory pins.",
    'match_found': 'Match Found!',
    'mic_denied': 'Microphone permission denied.',
    'settings_title': 'App Preferences',
    'pref_music_app': 'Preferred Music App',
    'pref_lang': 'Preferred Language',
    'open_spotify': 'Open in Spotify App',
    'open_apple': 'Open in Apple Music',
    'history_title': 'Search History',
    'clear_history': 'Clear History',
    'clear_history_confirm': 'Are you sure you want to delete all saved song searches?',
    'no_history': 'No songs searched yet!',
    'cancel': 'Cancel',
    'save': 'Save',
    'clear': 'Clear',
    'by': 'by',
    'User Manual': 'User Manual',
    'getting_started': 'Getting Started',
    'step 1': 'Set Your Preferences',
    'step1_desc': 'Choose Spotify or Apple Music, your preferred language, turn Auto Play on or off, and select your app theme.',
    'step 2': 'Choose Your Environment',
    'step2_desc': 'Choose Quiet, Loud, or Outdoors to help Reczt optimize recognition for your surroundings.',
    'step 3': 'Sing, Hum, or Play a Song',
    'step3_desc': 'Tap the microphone or use Siri to start recognition.',
    'step 4': 'Let Reczt Find the Best Match',
    'step4_desc': 'Reczt may use multiple recognition methods to identify your song. If a result is ambiguous, Reczt may ask you to choose between the most likely matches.',
    'step 5': 'Play the Result',
    'step5_desc': 'With Auto Play on, Reczt automatically opens the match in your preferred music app. If Reczt can’t open the exact track directly, it may open a search for the song and artist instead.',
    'step 6': 'Use Reczt Offline',
    'step6_desc': 'If you lose internet access, Reczt can save your recording and process it when connectivity returns.',
    'explore_more': 'Explore More',
    'step 7': 'Explore Your Reczt History',
    'step7_desc': 'Forgot which songs you’ve sung? Review previous songs and audio clips, or turn your History into a playlist in your preferred music app.',
    'step 8': 'Check Out Your Analytics',
    'step8_desc': 'Visit the Analytics page from the Home Screen to explore your recommended playlist, most-sung genres, top artist, daily streak, emotion pie chart, and Acoustic Memory map.',
    'step 9': 'Share with QuickShare',
    'step9_desc': 'Use QuickShare from the Analytics and History pages to share individual songs or your entire Analytics page across your favorite platforms.',
    'got it': 'Got it!',
    'Outdoors': 'Outdoors',
    'no_valid_match': 'No valid match met the dynamic confidence score. Try again!',
    'theme_title': 'App Color Theme',
    'theme_purple': 'Deep Purple',
    'theme_blue': 'Ocean Blue',
    'theme_emerald': 'Emerald',
    'theme_orange': 'Sunset Orange',
    'auto_play_title': 'Auto-play songs',
    'share_text': 'Check out "{title}" by {artist}, found hands-free using Reczt!',
    'pending_queue_title': 'Pending Offline Searches',
    'offline_saved': 'No internet. Saved to offline queue!',
     'analytics_title': 'Reczt Analytics',
      'streak_title': 'Singing Streak',
      'days_active_suffix': 'Days Active',
      'top_artist': 'Top Artist',
      'most_sung_genres': 'Most Sung Genres',
      'acoustic_map': 'Acoustic Memory Map',
      'acoustic_map_desc': '🗺️ Pins placed for recognized song locations',
      'vibe_match_playlist': 'Bi-Weekly Vibe\n Match Playlist',
      'playlist_countdown': 'Next auto-update in 4 days',
      'no_artist_data': 'Sing more songs to track your top artist!',
      'analyzing': 'Analyzing Mood...',
      'next_drop': 'Next Drop',
      'refreshing_soon': 'Refreshing soon!',
      'open_in': 'Open in',
      'none': 'None',
      'error_no_lyrics': 'Could not recognize lyrics. Try singing clearer!',
      'sad': 'Sad',
      'happy': 'Happy',
      'hype': 'Hype',
      'romantic': 'Romantic',
      'rock': 'Rock',
    'jazz': 'Jazz',
    'indie': 'Indie',
    'rap': 'Rap',
    'classical': 'Classical',
    'reggae': 'Reggae',
    'r&b': 'R&B',
    'pop': 'Pop',
    'open_in_platform': 'Open in {platform}',
    'songs': 'songs',
    'playlist_desc': 'Created automatically via Reczt App',
    'auth_spotify': 'Authenticating with Spotify...',
    'auth_failed': 'Spotify authorization canceled or failed.',
    'creating_playlist': 'Creating playlist and searching tracks...',
    'playlist_success': 'Success! Playlist created in Spotify.',
    'playlist_error': 'Could not create playlist. Make sure Spotify is connected.',
    'tap_to_play_preferred': 'Tap to play in your preferred app',
    'play_singing_sample': 'Play singing sample',
    'share_card': 'Share Card',
    'create_spotify_playlist': 'Create Spotify Playlist',
    'create_apple_playlist': 'Create Apple Music Playlist',
    'select_song_for_playlist': 'Select at least one song first.',
    'apple_music_connecting': 'Connecting to Apple Music...',
    'apple_playlist_creating': 'Creating Apple Music playlist...',
    'apple_playlist_success': 'Success! Playlist created in Apple Music.',
    'apple_playlist_partial': 'Playlist created in Apple Music: {added} added, {failed} not found.',
    'apple_playlist_error': 'Could not create the Apple Music playlist. Check Apple Music access and try again.',
    'analytics_share_text': 'Check out my music analytics on Reczt!',
    'calculating': 'Calculating...',
    'connection_failed': 'Failed to connect',
    'error_empty_path': 'Error: Recording path was empty.',
    'error_stopping': 'Error stopping recording',
    'live_pin_label': 'LIVE',
    'playlist_name': 'Reczt Music History',
    'quickshare_tooltip': 'QuickShare',
    'server_error': 'Server error',
    'unknown_artist': 'Unknown Artist',
    'opening_apple_search': 'Opening Apple Music search for',
    'processing_saved_recording': 'Processing Saved Recording...',
    'queued_song_found': 'Reczt has found your queued song!',
    'found_offline_badge': "Found Offline",
    'found_offline_detail': "Recognized from your offline queue",
    
  
    'waiting_for_voice': 'Waiting for your voice...',
    'signal_good': 'Good signal',
    'sing_louder': 'Sing a little louder',
    'top_guesses_title': 'Top guesses',
    'top_guesses_subtitle': 'I\'m not completely sure. Tap the song you meant.',
    'confidence': 'match',
    'retry_search': 'Retry last recording',
    'search_timed_out': 'Search took too long. Please retry.',
    'stop_recording': 'Stop recording',
    'other': 'Other',
  },
  'es': {
    "clear_this_data": '¿Borrar estos datos?',
    "clear_this_data_confirm": '¿Borrar solo los datos de {section}? Tus otros datos de Reczt se conservarán.',
    "data_box_cleared": 'Se borraron los datos de esta tarjeta.',
    "emotions": 'Emociones',
    "cleared": 'Borrado',
    'clear_reczt_data': 'Borrar datos de Reczt',
    'clear_reczt_data_desc': 'Borra del dispositivo el historial, clips de voz, estadísticas, pines de Memoria Acústica y grabaciones sin conexión en cola. Se conservan las preferencias de la app.',
    'clear_reczt_data_confirm': 'Esto eliminará permanentemente de este dispositivo el historial de canciones, clips de voz, estadísticas, ubicaciones de Memoria Acústica y grabaciones sin conexión en cola. Se conservarán el idioma, la app de música, el tema, Auto Play y las preferencias legales. Esta acción no se puede deshacer.',
    'clear_data_action': 'Borrar datos',
    'clear_reczt_data_success': 'Los datos de Reczt se borraron de este dispositivo.',
    'clear_reczt_data_error': 'Reczt no pudo borrar todos los datos locales. Inténtalo de nuevo.',
    'legal_privacy': 'Legal y privacidad',
    'privacy_policy': 'Política de privacidad',
    'terms_of_use': 'Términos de uso',
    'open_source_licenses': 'Licencias de código abierto',
    'legal_notice_title': 'Bienvenido a Reczt',
    'legal_notice_body': 'Antes de usar Reczt, revisa la Política de privacidad y los Términos de uso. Al tocar Aceptar y continuar, aceptas los Términos y reconoces la Política de privacidad.',
    'legal_accept': 'Aceptar y continuar',
    'legal_close': 'Cerrar',
    'view_online': 'Ver en línea',
    'app_title': 'Identificador de Canciones',
    'where_are_you': '¿Dónde estás?',
    'quiet_room': 'Una habitación silenciosa',
    'loud_room': 'Una habitación ruidosa con ruido de fondo',
    'initial_status': 'Selecciona tu entorno y toca el micrófono o di: "Oye Siri, activa Reczt".' ,
    'listening': 'Escuchando...',
    'searching': 'Buscando en la base de datos...',
    'enhanced_search': "Seguimos buscando — usando reconocimiento avanzado…",
    'location_pin_permission': "Permite el acceso a la ubicación para colocar pines de Memoria Acústica.",
    'match_found': '¡Coincidencia encontrada!',
    'mic_denied': 'Permiso de micrófono denegado.',
    'settings_title': 'Preferencias de la aplicación',
    'pref_music_app': 'Aplicación de música preferida',    'pref_lang': 'Idioma preferido',
    'open_spotify': 'Abrir en Spotify',
    'open_apple': 'Abrir en Apple Music',
    'history_title': 'Historial de búsqueda',
    'clear_history': 'Borrar historial',
    'clear_history_confirm': '¿Estás seguro de que deseas eliminar todas las búsquedas guardadas?',
    'no_history': '¡Aún no has buscado canciones!',
    'cancel': 'Cancelar',
    'save': 'Guardar',
    'clear': 'Borrar',
    'by': 'de',
    'User Manual': 'Cómo usar',
    'getting_started': 'Primeros pasos',
    'step 1': 'Configura tus preferencias',
    'step1_desc': 'Elige Spotify o Apple Music, tu idioma preferido, activa o desactiva Auto Play y selecciona el tema de la app.',
    'step 2': 'Elige tu entorno',
    'step2_desc': 'Elige Silencioso, Ruidoso o Al aire libre para ayudar a Reczt a optimizar el reconocimiento según tu entorno.',
    'step 3': 'Canta, tararea o reproduce una canción',
    'step3_desc': 'Toca el micrófono o usa Siri para iniciar el reconocimiento.',
    'step 4': 'Deja que Reczt encuentre la mejor coincidencia',
    'step4_desc': 'Reczt puede usar varios métodos de reconocimiento para identificar tu canción. Si el resultado es ambiguo, Reczt puede pedirte que elijas entre las coincidencias más probables.',
    'step 5': 'Reproduce el resultado',
    'step5_desc': 'Con Auto Play activado, Reczt abre automáticamente la coincidencia en tu app de música preferida. Si Reczt no puede abrir directamente la pista exacta, puede abrir una búsqueda de la canción y el artista.',
    'step 6': 'Usa Reczt sin conexión',
    'step6_desc': 'Si pierdes la conexión a internet, Reczt puede guardar tu grabación y procesarla cuando vuelva la conexión.',
    'explore_more': 'Explora más',
    'step 7': 'Explora tu historial de Reczt',
    'step7_desc': '¿Olvidaste qué canciones has cantado? Revisa canciones anteriores y clips de audio, o convierte tu Historial en una lista de reproducción en tu app de música preferida.',
    'step 8': 'Consulta tus Analytics',
    'step8_desc': 'Visita la página de Analytics desde la pantalla de inicio para explorar tu lista recomendada, géneros más cantados, artista principal, racha diaria, gráfico circular de emociones y mapa de Memoria Acústica.',
    'step 9': 'Comparte con QuickShare',
    'step9_desc': 'Usa QuickShare desde las páginas de Analytics e Historial para compartir canciones individuales o toda tu página de Analytics en tus plataformas favoritas.',
    'got it': '¡Entendido!',
    'Outdoors': 'Al aire libre',
    'no_valid_match': 'Ninguna coincidencia válida cumplió con la puntuación de confianza dinámica. ¡Inténtalo de nuevo!',
    'theme_title': 'Tema de color de la aplicación',
    'theme_purple': 'Púrpura profundo',
    'theme_blue': 'Azul océano',
    'theme_emerald': 'Esmeralda',
    'theme_orange': 'Naranja atardecer',
    'auto_play_title': 'Reproducción automática',
    'share_text': '¡Mira "{title}" de {artist}, encontrado sin manos usando Reczt!',
    'pending_queue_title': 'Búsquedas pendientes sin conexión',
    'offline_saved': '¡Sin internet! Guardado en la cola sin conexión.',
    'analytics_title': 'Reczt Analytics',
      'streak_title': 'Racha de canto',
      'days_active_suffix': 'Días activas',
      'top_artist': 'Principales artistas',
      'most_sung_genres': 'Géneros más cantados',
      'acoustic_map': 'Mapa de memoria acústica',
      'vibe_match_playlist': 'Lista de reproducción de coincidencias \n de vibe cada dos semanas',
      'playlist_countdown': 'Próxima actualización automática en 4 días',
      'no_artist_data': 'Canta más canciones para rastrear a las mejores artistas.',
      'analyzing': 'Analizando estado de ánimo...',
      'next_drop': 'Próxima actualización',
      'refreshing_soon': '¡Actualizando pronto!',
      'open_in': 'Abrir en',
      'none': 'Nada',
      'sad': 'Triste',
    'happy': 'Feliz',
    'hype': 'Animado',
    'romantic': 'Romántico',
    'rock': 'Rock',
    'jazz': 'Jazz',
    'indie': 'Indie',
    'rap': 'Rap',
    'classical': 'Clásica',
    'reggae': 'Reggae',
    'r&b': 'R&B',
    'pop': 'Pop',
    'error_no_lyrics': 'No se pudieron reconocer las letras. ¡Intenta cantar más claro!',
    'open_in_platform': 'Abrir en {platform}',
    'songs': 'canciones',
    'playlist_desc': 'Creado automáticamente mediante la aplicación Reczt',
    'auth_spotify': 'Autenticando con Spotify...',
    'auth_failed': 'Autorización de Spotify cancelada o fallida.',
    'creating_playlist': 'Creando lista de reproducción y buscando canciones...',
    'playlist_success': '¡Éxito! Lista de reproducción creada en Spotify.',
    'playlist_error': 'No se pudo crear la lista. Asegúrate de conectar Spotify.',
    'tap_to_play_preferred': 'Toca para reproducir en tu aplicación preferida',
    'play_singing_sample': 'Reproducir muestra de canto',
    'share_card': 'Tarjeta de compartir',
    'create_spotify_playlist': 'Crear lista en Spotify',
    'create_apple_playlist': 'Crear lista en Apple Music',
    'select_song_for_playlist': 'Selecciona al menos una canción primero.',
    'apple_music_connecting': 'Conectando con Apple Music...',
    'apple_playlist_creating': 'Creando lista de reproducción en Apple Music...',
    'apple_playlist_success': '¡Listo! Lista creada en Apple Music.',
    'apple_playlist_partial': 'Lista creada en Apple Music: {added} añadidas, {failed} no encontradas.',
    'apple_playlist_error': 'No se pudo crear la lista de Apple Music. Comprueba el acceso a Apple Music e inténtalo de nuevo.',
    'analytics_share_text': '¡Descubre mis estadísticas musicales en Reczt!',
    'calculating': 'Calculando...',
    'connection_failed': 'Error de conexión',
    'error_empty_path': 'Error: la ruta de la grabación estaba vacía.',
    'error_stopping': 'Error al detener la grabación',
    'live_pin_label': 'EN VIVO',
    'playlist_name': 'Historial musical de Reczt',
    'quickshare_tooltip': 'Compartir rápido',
    'server_error': 'Error del servidor',
    'unknown_artist': 'Artista desconocido',
    'opening_apple_search': 'Abriendo búsqueda en Apple Music para',
    'processing_saved_recording': 'Procesando grabación guardada...',
    'queued_song_found': '¡Reczt ha encontrado tu canción en espera!',
    'found_offline_badge': "Encontrada sin conexión",
    'found_offline_detail': "Reconocida desde tu cola sin conexión",
  
    'waiting_for_voice': 'Esperando tu voz...',
    'signal_good': 'Buena señal',
    'sing_louder': 'Canta un poco más fuerte',
    'top_guesses_title': 'Mejores opciones',
    'top_guesses_subtitle': 'No estoy completamente seguro. Toca la canción que querías.',
    'confidence': 'coincidencia',
    'retry_search': 'Reintentar la última grabación',
    'search_timed_out': 'La búsqueda tardó demasiado. Inténtalo de nuevo.',
    'stop_recording': 'Detener grabación',
    'other': 'Otro',
  },
  'fr': {
    "clear_this_data": 'Effacer ces données ?',
    "clear_this_data_confirm": 'Effacer uniquement les données de {section} ? Vos autres données Reczt seront conservées.',
    "data_box_cleared": 'Les données de cette carte ont été effacées.',
    "emotions": 'Émotions',
    "cleared": 'Effacé',
    'clear_reczt_data': 'Effacer les données Reczt',
    'clear_reczt_data_desc': 'Supprime de cet appareil l’historique, les extraits chantés, les statistiques, les repères de Mémoire acoustique et les enregistrements hors ligne en attente. Les préférences de l’app sont conservées.',
    'clear_reczt_data_confirm': 'Cette action supprimera définitivement de cet appareil votre historique de chansons, vos extraits chantés, vos statistiques, les emplacements de Mémoire acoustique et les enregistrements hors ligne en attente. La langue, l’app musicale, le thème, Auto Play et les préférences juridiques seront conservés. Cette action est irréversible.',
    'clear_data_action': 'Effacer les données',
    'clear_reczt_data_success': 'Les données Reczt ont été effacées de cet appareil.',
    'clear_reczt_data_error': 'Reczt n’a pas pu effacer toutes les données locales. Réessayez.',
    'legal_privacy': 'Mentions légales et confidentialité',
    'privacy_policy': 'Politique de confidentialité',
    'terms_of_use': 'Conditions d’utilisation',
    'open_source_licenses': 'Licences open source',
    'legal_notice_title': 'Bienvenue dans Reczt',
    'legal_notice_body': 'Avant d’utiliser Reczt, veuillez consulter la Politique de confidentialité et les Conditions d’utilisation. En touchant Accepter et continuer, vous acceptez les Conditions et reconnaissez la Politique de confidentialité.',
    'legal_accept': 'Accepter et continuer',
    'legal_close': 'Fermer',
    'view_online': 'Voir en ligne',
    'app_title': 'Identificateur de Chansons',
    'where_are_you': 'Où êtes-vous ?',
    'quiet_room': 'Une pièce calme',
    'loud_room': 'Une pièce bruyante avec du bruit de fond',
    'initial_status': 'Sélectionnez votre environnement et appuyez sur le micro, ou dites "Dis Siri, active Reczt"!.',
    'listening': 'Écoute en cours...',
    'searching': 'Recherche dans la base de données...',
    'enhanced_search': "Recherche en cours — reconnaissance avancée…",
    'location_pin_permission': "Autorisez l’accès à la localisation pour placer les repères de mémoire acoustique.",
    'match_found': 'Correspondance trouvée !',
    'mic_denied': 'Autorisation du microphone refusée.',
    'settings_title': 'Préférences de l\'application',
    'pref_music_app': 'Application de musique préférée',    'pref_lang': 'Langue préférée',
    'open_spotify': 'Ouvrir dans Spotify',
    'open_apple': 'Ouvrir dans Apple Music',
    'history_title': 'Historique des recherches',
    'clear_history': 'Effacer l\'historique',
    'clear_history_confirm': 'Voulez-vous vraiment supprimer toutes les recherches enregistrées ?',
    'no_history': 'Aucune chanson recherchée pour l\'instant !',
    'cancel': 'Annuler',
    'save': 'Enregistrer',
    'clear': 'Effacer',
    'by': 'par',
    'User Manual': 'Comment utiliser',
    'getting_started': 'Bien démarrer',
    'step 1': 'Configurez vos préférences',
    'step1_desc': 'Choisissez Spotify ou Apple Music, votre langue préférée, activez ou désactivez Auto Play et sélectionnez le thème de l’app.',
    'step 2': 'Choisissez votre environnement',
    'step2_desc': 'Choisissez Calme, Bruyant ou Extérieur pour aider Reczt à optimiser la reconnaissance selon votre environnement.',
    'step 3': 'Chantez, fredonnez ou lancez une chanson',
    'step3_desc': 'Touchez le microphone ou utilisez Siri pour démarrer la reconnaissance.',
    'step 4': 'Laissez Reczt trouver la meilleure correspondance',
    'step4_desc': 'Reczt peut utiliser plusieurs méthodes de reconnaissance pour identifier votre chanson. Si le résultat est ambigu, Reczt peut vous demander de choisir parmi les correspondances les plus probables.',
    'step 5': 'Écoutez le résultat',
    'step5_desc': 'Avec Auto Play activé, Reczt ouvre automatiquement la correspondance dans votre app musicale préférée. Si Reczt ne peut pas ouvrir directement le morceau exact, il peut lancer une recherche avec le titre et l’artiste.',
    'step 6': 'Utilisez Reczt hors ligne',
    'step6_desc': 'Si vous perdez votre connexion Internet, Reczt peut enregistrer votre enregistrement et le traiter lorsque la connexion revient.',
    'explore_more': 'Explorer davantage',
    'step 7': 'Explorez votre historique Reczt',
    'step7_desc': 'Vous avez oublié les chansons que vous avez chantées ? Consultez vos chansons précédentes et vos extraits audio, ou transformez votre Historique en playlist dans votre app musicale préférée.',
    'step 8': 'Consultez vos Analytics',
    'step8_desc': 'Depuis l’écran d’accueil, ouvrez la page Analytics pour découvrir votre playlist recommandée, vos genres les plus chantés, votre artiste principal, votre série quotidienne, le graphique circulaire des émotions et la carte Acoustic Memory.',
    'step 9': 'Partagez avec QuickShare',
    'step9_desc': 'Utilisez QuickShare depuis les pages Analytics et Historique pour partager des chansons individuelles ou l’ensemble de votre page Analytics sur vos plateformes préférées.',
    'got it': 'Compris !',
    'Outdoors': 'En plein air',
    'no_valid_match': 'Aucune correspondance valide n\'a atteint le score de confiance dynamique. Réessayez !',
    'theme_title': 'Thème de couleur de l\'application',
    'theme_purple': 'Violet profond',
    'theme_blue': 'Bleu océan',
    'theme_emerald': 'Émeraude',
    'theme_orange': 'Orange crépuscule',
    'auto_play_title': 'Lecture automatique',
    'share_text': 'Découvrez "{title}" de {artist}, trouvé sans les mains grâce à Reczt !',
    'pending_queue_title': 'Recherches hors ligne en attente',
    'offline_saved': 'Pas d\'internet. Enregistré dans la file d\'attente hors ligne !',
    'analytics_title': 'Reczt Analytics',
      'streak_title': 'Série de chants',
      'days_active_suffix': 'Jours actifs',
      'top_artist': 'Meilleurs Artistes',
      'most_sung_genres': 'Genres les plus chantés',
      'acoustic_map': 'Carte de mémoire acoustique',
      'vibe_match_playlist': 'Playlist Vibe Matc \n bi-hebdomadaire',
      'playlist_countdown': 'Prochaine mise à jour auto dans 4 jours',
      'no_artist_data': 'Chantez plus de chansons pour suivre vos artistes !',
      'analyzing': 'Analyse de l’humeur...',
      'next_drop': 'Prochaine mise à jour',
      'refreshing_soon': 'Mise à jour prochaine !',
      'open_in': 'Ouvrir dans',
      'none': 'Aucune',
      'sad': 'Triste',
    'happy': 'Heureux',
    'hype': 'Survolté',
    'romantic': 'Romantique',
    'rock': 'Rock',
    'jazz': 'Jazz',
    'indie': 'Indie',
    'rap': 'Rap',
    'classical': 'Classique',
    'reggae': 'Reggae',
    'r&b': 'R&B',
    'pop': 'Pop',
    'error_no_lyrics': 'Impossible de reconnaître les paroles. Essayez de chanter plus clairement !',
    'open_in_platform': 'Ouvrir dans {platform}',
    'songs': 'chansons',
    'playlist_desc': 'Créé automatiquement via l\'application Reczt',
    'auth_spotify': 'Authentification avec Spotify...',
    'auth_failed': 'Autorisation Spotify annulée ou échouée.',
    'creating_playlist': 'Création de la playlist et recherche des morceaux...',
    'playlist_success': 'Succès ! Playlist créée sur Spotify.',
    'playlist_error': 'Impossible de créer la playlist. Vérifiez que Spotify est connecté.',
    'tap_to_play_preferred': 'Appuyez pour lire dans votre application préférée',
    'play_singing_sample': 'Écouter un extrait chanté',
    'share_card': 'Carte de partage',
    'create_spotify_playlist': 'Créer une playlist Spotify',
    'create_apple_playlist': 'Créer une playlist Apple Music',
    'select_song_for_playlist': 'Sélectionnez d’abord au moins un morceau.',
    'apple_music_connecting': 'Connexion à Apple Music…',
    'apple_playlist_creating': 'Création de la playlist Apple Music…',
    'apple_playlist_success': 'Succès ! Playlist créée dans Apple Music.',
    'apple_playlist_partial': 'Playlist créée dans Apple Music : {added} ajoutés, {failed} introuvables.',
    'apple_playlist_error': 'Impossible de créer la playlist Apple Music. Vérifiez l’accès à Apple Music et réessayez.',
    'analytics_share_text': 'Découvrez mes statistiques musicales sur Reczt !',
    'calculating': 'Calcul en cours...',
    'connection_failed': 'Échec de la connexion',
    'error_empty_path': 'Erreur : le chemin de l\'enregistrement était vide.',
    'error_stopping': 'Erreur lors de l\'arrêt de l\'enregistrement',
    'live_pin_label': 'EN DIRECT',
    'playlist_name': 'Historique musical Reczt',
    'quickshare_tooltip': 'Partage rapide',
    'server_error': 'Erreur du serveur',
    'unknown_artist': 'Artiste inconnu',
    'opening_apple_search': 'Ouverture de la recherche Apple Music pour',
    'processing_saved_recording': 'Traitement de l\'enregistrement sauvegardé...',
    'queued_song_found': 'Reczt a trouvé votre chanson en attente !',
    'found_offline_badge': "Trouvée hors ligne",
    'found_offline_detail': "Reconnue depuis votre file hors ligne",
  
    'waiting_for_voice': 'En attente de votre voix...',
    'signal_good': 'Bon signal',
    'sing_louder': 'Chantez un peu plus fort',
    'top_guesses_title': 'Meilleures suggestions',
    'top_guesses_subtitle': 'Je ne suis pas totalement sûr. Touchez la chanson que vous vouliez.',
    'confidence': 'correspondance',
    'retry_search': 'Réessayer le dernier enregistrement',
    'search_timed_out': 'La recherche a pris trop de temps. Réessayez.',
    'stop_recording': 'Arrêter l’enregistrement',
    'other': 'Autre',
  },
  'de': {
    "clear_this_data": 'Diese Daten löschen?',
    "clear_this_data_confirm": 'Nur die Daten für {section} löschen? Deine anderen Reczt-Daten bleiben erhalten.',
    "data_box_cleared": 'Die Daten dieser Karte wurden gelöscht.',
    "emotions": 'Emotionen',
    "cleared": 'Gelöscht',
    'clear_reczt_data': 'Reczt-Daten löschen',
    'clear_reczt_data_desc': 'Löscht Verlauf, Gesangsclips, Analysen, Acoustic-Memory-Pins und wartende Offline-Aufnahmen von diesem Gerät. App-Einstellungen bleiben erhalten.',
    'clear_reczt_data_confirm': 'Dadurch werden dein Songverlauf, Gesangsclips, Analysen, Acoustic-Memory-Standorte und wartende Offline-Aufnahmen dauerhaft von diesem Gerät gelöscht. Sprache, Musik-App, Design, Auto Play und rechtliche Einstellungen bleiben erhalten. Dies kann nicht rückgängig gemacht werden.',
    'clear_data_action': 'Daten löschen',
    'clear_reczt_data_success': 'Die Reczt-Daten wurden von diesem Gerät gelöscht.',
    'clear_reczt_data_error': 'Reczt konnte nicht alle lokalen Daten löschen. Bitte versuche es erneut.',
    'legal_privacy': 'Rechtliches & Datenschutz',
    'privacy_policy': 'Datenschutzerklärung',
    'terms_of_use': 'Nutzungsbedingungen',
    'open_source_licenses': 'Open-Source-Lizenzen',
    'legal_notice_title': 'Willkommen bei Reczt',
    'legal_notice_body': 'Bitte lies vor der Nutzung von Reczt die Datenschutzerklärung und die Nutzungsbedingungen. Mit Zustimmen & Fortfahren akzeptierst du die Bedingungen und bestätigst die Datenschutzerklärung.',
    'legal_accept': 'Zustimmen & fortfahren',
    'legal_close': 'Schließen',
    'view_online': 'Online ansehen',
    'app_title': 'Song-Erkennung',
    'where_are_you': 'Wo bist du?',
    'quiet_room': 'Ein ruhiger Raum',
    'loud_room': 'Ein lauter Raum mit Hintergrundgeräuschen',
    'initial_status': 'Wähle deine Umgebung aus und tippe auf das Mikrofon oder sage: "Hey Siri, aktiviere Reczt"!',
    'listening': 'Zuhören...',
    'searching': 'Datenbank wird durchsucht...',
    'enhanced_search': "Suche läuft weiter – erweiterte Erkennung wird verwendet…",
    'location_pin_permission': "Erlaube den Standortzugriff, um Acoustic-Memory-Pins zu setzen.",
    'match_found': 'Treffer gefunden!',
    'mic_denied': 'Mikrofonberechtigung verweigert.',
    'settings_title': 'App-Einstellungen',
    'pref_music_app': 'Bevorzugte Musik-App',    'pref_lang': 'Bevorzugte Sprache',
    'open_spotify': 'In Spotify öffnen',
    'open_apple': 'In Apple Music öffnen',
    'history_title': 'Suchverlauf',
    'clear_history': 'Verlauf löschen',
    'clear_history_confirm': 'Möchtest du wirklich alle gespeicherten Suchen löschen?',
    'no_history': 'Noch keine Songs gesucht!',
    'cancel': 'Abbrechen',
    'save': 'Speichern',
    'clear': 'Löschen',
    'by': 'von',
    'User Manual': 'Wie man es benutzt',
    'getting_started': 'Erste Schritte',
    'step 1': 'Lege deine Einstellungen fest',
    'step1_desc': 'Wähle Spotify oder Apple Music, deine bevorzugte Sprache, schalte Auto Play ein oder aus und wähle dein App-Design.',
    'step 2': 'Wähle deine Umgebung',
    'step2_desc': 'Wähle Ruhig, Laut oder Draußen, damit Reczt die Erkennung an deine Umgebung anpassen kann.',
    'step 3': 'Singe, summe oder spiele einen Song ab',
    'step3_desc': 'Tippe auf das Mikrofon oder verwende Siri, um die Erkennung zu starten.',
    'step 4': 'Lass Reczt die beste Übereinstimmung finden',
    'step4_desc': 'Reczt kann mehrere Erkennungsmethoden verwenden, um deinen Song zu identifizieren. Ist das Ergebnis nicht eindeutig, kann Reczt dich bitten, zwischen den wahrscheinlichsten Treffern zu wählen.',
    'step 5': 'Spiele das Ergebnis ab',
    'step5_desc': 'Wenn Auto Play aktiviert ist, öffnet Reczt den Treffer automatisch in deiner bevorzugten Musik-App. Kann Reczt den exakten Titel nicht direkt öffnen, wird möglicherweise stattdessen eine Suche nach Song und Künstler geöffnet.',
    'step 6': 'Nutze Reczt offline',
    'step6_desc': 'Wenn du die Internetverbindung verlierst, kann Reczt deine Aufnahme speichern und verarbeiten, sobald die Verbindung wiederhergestellt ist.',
    'explore_more': 'Mehr entdecken',
    'step 7': 'Entdecke deinen Reczt-Verlauf',
    'step7_desc': 'Vergessen, welche Songs du gesungen hast? Sieh dir frühere Songs und Audioclips an oder verwandle deinen Verlauf in deiner bevorzugten Musik-App in eine Playlist.',
    'step 8': 'Sieh dir deine Analytics an',
    'step8_desc': 'Öffne die Analytics-Seite vom Startbildschirm aus, um deine empfohlene Playlist, meistgesungenen Genres, Top-Künstler, tägliche Serie, Emotions-Kreisdiagramm und Acoustic-Memory-Karte zu entdecken.',
    'step 9': 'Mit QuickShare teilen',
    'step9_desc': 'Verwende QuickShare auf den Seiten Analytics und Verlauf, um einzelne Songs oder deine gesamte Analytics-Seite über deine bevorzugten Plattformen zu teilen.',
    'got it': 'Verstanden!',
    'Outdoors': 'Draußen',
    'no_valid_match': 'Kein gültiger Treffer hat die dynamische Vertrauenspunktzahl erreicht. Versuche es erneut!',
    'theme_title': 'App-Farbthema',
    'theme_purple': 'Tiefes Lila',
    'theme_blue': 'Ozeanblau',
    'theme_emerald': 'Smaragd',
    'theme_orange': 'Sonnenuntergangsorange',
    'auto_play_title': 'Automatische Wiedergabe',
    'share_text': 'Schau dir "{title}" von {artist} an, gefunden freihändig mit Reczt!',
    'pending_queue_title': 'Ausstehende Offline-Suchen',
    'offline_saved': 'Keine Internetverbindung. In die Offline-Warteschlange gespeichert!',
    'analytics_title': 'Reczt Analytics',
      'streak_title': 'Gesangsserie',
      'days_active_suffix': 'Tage aktiv',
      'top_artist': 'Top-Künstler',
      'most_sung_genres': 'Meist gesungene Genres',
      'acoustic_map': 'Akustische Erinnerungslandkarte',
      'vibe_match_playlist': 'Zweiwöchentliche \n Vibe-Match-Playlist',
      'playlist_countdown': 'Nächste automatische Aktualisierung in 4 Tagen',
      'no_artist_data': 'Singe mehr Songs, um Top-Künstler zu verfolgen!',
      'analyzing': 'Stimmung wird analysiert...',
      'next_drop': 'Nächster Drop',
      'refreshing_soon': 'Wird bald aktualisiert!',
      'open_in': 'Öffnen in',
      'none': 'Keiner',
      'sad': 'Traurig',
    'happy': 'Glücklich',
    'hype': 'Begeistert',
    'romantic': 'Romantisch',
    'rock': 'Rock',
    'jazz': 'Jazz',
    'indie': 'Indie',
    'rap': 'Rap',
    'classical': 'Klassik',
    'reggae': 'Reggae',
    'r&b': 'R&B',
    'pop': 'Pop',
    'error_no_lyrics': 'Songtext konnte nicht erkannt werden. Versuche, deutlicher zu singen!',
    'open_in_platform': 'In {platform} öffnen',
    'songs': 'Songs',
    'playlist_desc': 'Automatisch erstellt über die Reczt-App',
    'auth_spotify': 'Authentifizierung mit Spotify...',
    'auth_failed': 'Spotify-Autorisierung abgebrochen oder fehlgeschlagen.',
    'creating_playlist': 'Playlist wird erstellt und Titel werden gesucht...',
    'playlist_success': 'Erfolg! Playlist auf Spotify erstellt.',
    'playlist_error': 'Playlist konnte nicht erstellt werden. Prüfe die Verbindung.',
    'tap_to_play_preferred': 'Tippen zum Abspielen in bevorzugter App',
    'play_singing_sample': 'Gesangsprobe abspielen',
    'share_card': 'Teilen-Karte',
    'create_spotify_playlist': 'Spotify-Playlist erstellen',
    'create_apple_playlist': 'Apple Music-Playlist erstellen',
    'select_song_for_playlist': 'Wähle zuerst mindestens einen Song aus.',
    'apple_music_connecting': 'Verbindung mit Apple Music...',
    'apple_playlist_creating': 'Apple Music-Playlist wird erstellt...',
    'apple_playlist_success': 'Erfolg! Playlist in Apple Music erstellt.',
    'apple_playlist_partial': 'Playlist in Apple Music erstellt: {added} hinzugefügt, {failed} nicht gefunden.',
    'apple_playlist_error': 'Die Apple Music-Playlist konnte nicht erstellt werden. Prüfe den Apple Music-Zugriff und versuche es erneut.',
    'analytics_share_text': 'Sieh dir meine Musikstatistiken auf Reczt an!',
    'calculating': 'Wird berechnet...',
    'connection_failed': 'Verbindung fehlgeschlagen',
    'error_empty_path': 'Fehler: Der Aufnahmepfad war leer.',
    'error_stopping': 'Fehler beim Stoppen der Aufnahme',
    'live_pin_label': 'LIVE',
    'playlist_name': 'Reczt Musikverlauf',
    'quickshare_tooltip': 'Schnell teilen',
    'server_error': 'Serverfehler',
    'unknown_artist': 'Unbekannter Künstler',
    'opening_apple_search': 'Apple-Music-Suche wird geöffnet für',
    'processing_saved_recording': 'Gespeicherte Aufnahme wird verarbeitet...',
    'queued_song_found': 'Reczt hat deinen wartenden Song gefunden!',
    'found_offline_badge': "Offline gefunden",
    'found_offline_detail': "Aus deiner Offline-Warteschlange erkannt",
  
    'waiting_for_voice': 'Warte auf deine Stimme...',
    'signal_good': 'Gutes Signal',
    'sing_louder': 'Sing etwas lauter',
    'top_guesses_title': 'Beste Treffer',
    'top_guesses_subtitle': 'Ich bin mir nicht ganz sicher. Tippe auf den gemeinten Song.',
    'confidence': 'Treffer',
    'retry_search': 'Letzte Aufnahme erneut versuchen',
    'search_timed_out': 'Die Suche hat zu lange gedauert. Bitte erneut versuchen.',
    'stop_recording': 'Aufnahme stoppen',
    'other': 'Andere',
  },
  'it': {
    "clear_this_data": 'Cancellare questi dati?',
    "clear_this_data_confirm": 'Cancellare solo i dati di {section}? Gli altri dati Reczt resteranno invariati.',
    "data_box_cleared": 'I dati di questa scheda sono stati cancellati.',
    "emotions": 'Emozioni',
    "cleared": 'Cancellato',
    'clear_reczt_data': 'Cancella dati Reczt',
    'clear_reczt_data_desc': 'Elimina da questo dispositivo cronologia, clip cantate, statistiche, pin di Memoria Acustica e registrazioni offline in coda. Le preferenze dell’app vengono mantenute.',
    'clear_reczt_data_confirm': 'Questa azione eliminerà definitivamente da questo dispositivo la cronologia dei brani, le clip cantate, le statistiche, le posizioni di Memoria Acustica e le registrazioni offline in coda. Lingua, app musicale, tema, Auto Play e preferenze legali verranno mantenuti. L’operazione non può essere annullata.',
    'clear_data_action': 'Cancella dati',
    'clear_reczt_data_success': 'I dati Reczt sono stati cancellati da questo dispositivo.',
    'clear_reczt_data_error': 'Reczt non è riuscito a cancellare tutti i dati locali. Riprova.',
    'legal_privacy': 'Note legali e privacy',
    'privacy_policy': 'Informativa sulla privacy',
    'terms_of_use': 'Termini di utilizzo',
    'open_source_licenses': 'Licenze open source',
    'legal_notice_title': 'Benvenuto in Reczt',
    'legal_notice_body': 'Prima di usare Reczt, consulta l’Informativa sulla privacy e i Termini di utilizzo. Toccando Accetta e continua, accetti i Termini e prendi atto dell’Informativa sulla privacy.',
    'legal_accept': 'Accetta e continua',
    'legal_close': 'Chiudi',
    'view_online': 'Visualizza online',
    'app_title': 'Riconoscimento Brani',
    'where_are_you': 'Dove ti trovi?',
    'quiet_room': 'Una stanza silenziosa',
    'loud_room': 'Una stanza rumorosa',
    'initial_status': 'Seleziona l\'ambiente e tocca il microfono o dicci: "Hey Siri, attiva Reczt"!',
    'listening': 'Ascolto in corso...',
    'searching': 'Ricerca nel database...',
    'enhanced_search': "Ricerca in corso — uso del riconoscimento avanzato…",
    'location_pin_permission': "Consenti l’accesso alla posizione per aggiungere i pin della Memoria Acustica.",
    'match_found': 'Brano trovato!',
    'mic_denied': 'Autorizzazione microfono negata.',
    'settings_title': 'Preferenze App',
    'pref_music_app': 'App musicale preferita',    'pref_lang': 'Lingua preferita',
    'open_spotify': 'Apri su Spotify',
    'open_apple': 'Apri su Apple Music',
    'history_title': 'Cronologia ricerche',
    'clear_history': 'Cancella cronologia',
    'clear_history_confirm': 'Sei sicuro di voler eliminare tutta la cronologia?',
    'no_history': 'Nessun brano cercato finora!',
    'cancel': 'Annulla',
    'save': 'Salva',
    'clear': 'Cancella',
    'by': 'di',
    'User Manual': 'Come usare',
    'getting_started': 'Per iniziare',
    'step 1': 'Imposta le tue preferenze',
    'step1_desc': 'Scegli Spotify o Apple Music, la lingua preferita, attiva o disattiva Auto Play e seleziona il tema dell’app.',
    'step 2': 'Scegli il tuo ambiente',
    'step2_desc': 'Scegli Silenzioso, Rumoroso o All’aperto per aiutare Reczt a ottimizzare il riconoscimento in base all’ambiente.',
    'step 3': 'Canta, canticchia o riproduci una canzone',
    'step3_desc': 'Tocca il microfono o usa Siri per avviare il riconoscimento.',
    'step 4': 'Lascia che Reczt trovi la corrispondenza migliore',
    'step4_desc': 'Reczt può usare più metodi di riconoscimento per identificare la tua canzone. Se il risultato è ambiguo, Reczt può chiederti di scegliere tra le corrispondenze più probabili.',
    'step 5': 'Riproduci il risultato',
    'step5_desc': 'Con Auto Play attivo, Reczt apre automaticamente la corrispondenza nella tua app musicale preferita. Se Reczt non riesce ad aprire direttamente la traccia esatta, può aprire una ricerca per canzone e artista.',
    'step 6': 'Usa Reczt offline',
    'step6_desc': 'Se perdi la connessione a Internet, Reczt può salvare la registrazione e processarla quando la connessione ritorna.',
    'explore_more': 'Scopri di più',
    'step 7': 'Esplora la cronologia di Reczt',
    'step7_desc': 'Hai dimenticato quali canzoni hai cantato? Rivedi le canzoni precedenti e i clip audio, oppure trasforma la Cronologia in una playlist nella tua app musicale preferita.',
    'step 8': 'Scopri i tuoi Analytics',
    'step8_desc': 'Visita la pagina Analytics dalla schermata Home per esplorare la playlist consigliata, i generi più cantati, l’artista principale, la serie giornaliera, il grafico a torta delle emozioni e la mappa Acoustic Memory.',
    'step 9': 'Condividi con QuickShare',
    'step9_desc': 'Usa QuickShare dalle pagine Analytics e Cronologia per condividere singole canzoni o l’intera pagina Analytics sulle tue piattaforme preferite.',
    'got it': 'Capito!',
    'Outdoors': 'All\'aperto',
    'no_valid_match': 'Nessuna corrispondenza valida ha raggiunto il punteggio di fiducia dinamico. Riprova!',
    'theme_title': 'Tema colore app',
    'theme_purple': 'Viola intenso',
    'theme_blue': 'Blu oceano',
    'theme_emerald': 'Smeraldo',
    'theme_orange': 'Arancione tramonto',
    'auto_play_title': 'Riproduzione automatica',
    'share_text': 'Controlla "{title}" di {artist}, trovata senza mani usando Reczt!',
    'pending_queue_title': 'Ricerche in attesa offline',
    'offline_saved': 'Nessuna connessione. Salvato nella coda offline!',
'analytics_title': 'Analisi Reczt',
      'streak_title': 'Serie di canti',
      'days_active_suffix': 'Giorni attivi',
      'top_artist': 'Artisti principali',
      'most_sung_genres': 'Generi più cantati',
      'acoustic_map': 'Carta della memoria acustica',
      'vibe_match_playlist': 'Playlist di corrispondenza \n Vibe bisettimanale',
      'playlist_countdown': 'Prossimo aggiornamento automatico tra 4 giorni',
      'no_artist_data': 'Canta più brani per tracciare i tuoi artisti!',
      'analyzing': 'Analisi umore...',
      'next_drop': 'Prossimo aggiornamento',
      'refreshing_soon': 'Aggiornamento imminente!',
      'open_in': 'Apri in',
      'none': 'Nessuno',
      'sad': 'Triste',
    'happy': 'Felice',
    'hype': 'Esaltato',
    'romantic': 'Romantico',
    'rock': 'Rock',
    'jazz': 'Jazz',
    'indie': 'Indie',
    'rap': 'Rap',
    'classical': 'Classica',
    'reggae': 'Reggae',
    'r&b': 'R&B',
    'pop': 'Pop',
    'error_no_lyrics': 'Impossibile riconoscere il testo. Prova a cantare più chiaramente!',
    'open_in_platform': 'Apri in {platform}',
    'songs': 'canzoni',
    'playlist_desc': 'Creato automaticamente tramite l\'app Reczt',
    'auth_spotify': 'Autenticazione con Spotify...',
    'auth_failed': 'Autorizzazione Spotify annullata o non riuscita.',
    'creating_playlist': 'Creazione playlist e ricerca brani in corso...',
    'playlist_success': 'Operazione completata! Playlist creata su Spotify.',
    'playlist_error': 'Impossibile creare la playlist. Assicurati che Spotify sia connesso.',
    'tap_to_play_preferred': 'Tocca per riprodurre nell\'app preferita',
    'play_singing_sample': 'Riproduci campione di canto',
    'share_card': 'Scheda di condivisione',
    'create_spotify_playlist': 'Crea playlist Spotify',
    'create_apple_playlist': 'Crea playlist Apple Music',
    'select_song_for_playlist': 'Seleziona prima almeno un brano.',
    'apple_music_connecting': 'Connessione ad Apple Music...',
    'apple_playlist_creating': 'Creazione della playlist Apple Music...',
    'apple_playlist_success': 'Operazione completata! Playlist creata in Apple Music.',
    'apple_playlist_partial': 'Playlist creata in Apple Music: {added} aggiunti, {failed} non trovati.',
    'apple_playlist_error': 'Impossibile creare la playlist Apple Music. Controlla l’accesso ad Apple Music e riprova.',
    'analytics_share_text': 'Guarda le mie statistiche musicali su Reczt!',
    'calculating': 'Calcolo in corso...',
    'connection_failed': 'Connessione non riuscita',
    'error_empty_path': 'Errore: il percorso della registrazione era vuoto.',
    'error_stopping': 'Errore durante l\'arresto della registrazione',
    'live_pin_label': 'LIVE',
    'playlist_name': 'Cronologia musicale Reczt',
    'quickshare_tooltip': 'Condivisione rapida',
    'server_error': 'Errore del server',
    'unknown_artist': 'Artista sconosciuto',
    'opening_apple_search': 'Apertura ricerca Apple Music per',
    'processing_saved_recording': 'Elaborazione registrazione salvata...',
    'queued_song_found': 'Reczt ha trovato la tua canzone in coda!',
    'found_offline_badge': "Trovata offline",
    'found_offline_detail': "Riconosciuta dalla tua coda offline",
  
    'waiting_for_voice': 'In attesa della tua voce...',
    'signal_good': 'Segnale buono',
    'sing_louder': 'Canta un po’ più forte',
    'top_guesses_title': 'Migliori ipotesi',
    'top_guesses_subtitle': 'Non sono del tutto sicuro. Tocca la canzone che intendevi.',
    'confidence': 'corrispondenza',
    'retry_search': 'Riprova l’ultima registrazione',
    'search_timed_out': 'La ricerca ha impiegato troppo tempo. Riprova.',
    'stop_recording': 'Interrompi registrazione',
    'other': 'Altro',
  },
  'pt': {
    "clear_this_data": 'Limpar estes dados?',
    "clear_this_data_confirm": 'Limpar apenas os dados de {section}? Os outros dados do Reczt serão mantidos.',
    "data_box_cleared": 'Os dados deste cartão foram limpos.',
    "emotions": 'Emoções',
    "cleared": 'Limpo',
    'clear_reczt_data': 'Limpar dados do Reczt',
    'clear_reczt_data_desc': 'Apaga deste dispositivo o histórico, clipes de canto, análises, pinos da Memória Acústica e gravações offline na fila. As preferências do app são mantidas.',
    'clear_reczt_data_confirm': 'Isso apagará permanentemente deste dispositivo seu histórico de músicas, clipes de canto, análises, locais da Memória Acústica e gravações offline na fila. Idioma, app de música, tema, Auto Play e preferências legais serão mantidos. Esta ação não pode ser desfeita.',
    'clear_data_action': 'Limpar dados',
    'clear_reczt_data_success': 'Os dados do Reczt foram apagados deste dispositivo.',
    'clear_reczt_data_error': 'O Reczt não conseguiu apagar todos os dados locais. Tente novamente.',
    'legal_privacy': 'Legal e privacidade',
    'privacy_policy': 'Política de Privacidade',
    'terms_of_use': 'Termos de Uso',
    'open_source_licenses': 'Licenças de código aberto',
    'legal_notice_title': 'Bem-vindo ao Reczt',
    'legal_notice_body': 'Antes de usar o Reczt, revise a Política de Privacidade e os Termos de Uso. Ao tocar em Aceitar e continuar, você aceita os Termos e reconhece a Política de Privacidade.',
    'legal_accept': 'Aceitar e continuar',
    'legal_close': 'Fechar',
    'view_online': 'Ver online',
    'app_title': 'Identificador de Músicas',
    'where_are_you': 'Onde você está?',
    'quiet_room': 'Um quarto silencioso',
    'loud_room': 'Um ambiente barulhento',
    'initial_status': 'Selecione seu ambiente e toque no microfone ou diga: "Oye Siri, ative Reczt"!',
    'listening': 'Ouvindo...',
    'searching': 'Buscando no banco de dados...',
    'enhanced_search': "Ainda procurando — usando reconhecimento avançado…",
    'location_pin_permission': "Permita o acesso à localização para adicionar pinos de Memória Acústica.",
    'match_found': 'Música encontrada!',
    'mic_denied': 'Permissão do microfone negada.',
    'settings_title': 'Preferências do App',
    'pref_music_app': 'Aplicativo de música preferido',    'pref_lang': 'Idioma preferido',
    'open_spotify': 'Abrir no Spotify',
    'open_apple': 'Abrir no Apple Music',
    'history_title': 'Histórico de busca',
    'clear_history': 'Limpar histórico',
    'clear_history_confirm': 'Tem certeza que deseja apagar o histórico?',
    'no_history': 'Nenhuma música buscada ainda!',
    'cancel': 'Cancelar',
    'save': 'Salvar',
    'clear': 'Limpar',
    'by': 'de',
    'User Manual': 'Como usar',
    'getting_started': 'Primeiros passos',
    'step 1': 'Defina suas preferências',
    'step1_desc': 'Escolha Spotify ou Apple Music, seu idioma preferido, ative ou desative o Auto Play e selecione o tema do app.',
    'step 2': 'Escolha seu ambiente',
    'step2_desc': 'Escolha Silencioso, Barulhento ou Ao ar livre para ajudar o Reczt a otimizar o reconhecimento para o seu ambiente.',
    'step 3': 'Cante, cantarole ou reproduza uma música',
    'step3_desc': 'Toque no microfone ou use a Siri para iniciar o reconhecimento.',
    'step 4': 'Deixe o Reczt encontrar a melhor correspondência',
    'step4_desc': 'O Reczt pode usar vários métodos de reconhecimento para identificar sua música. Se o resultado for ambíguo, o Reczt poderá pedir que você escolha entre as correspondências mais prováveis.',
    'step 5': 'Reproduza o resultado',
    'step5_desc': 'Com o Auto Play ativado, o Reczt abre automaticamente a correspondência no seu app de música preferido. Se não conseguir abrir diretamente a faixa exata, ele poderá abrir uma busca pela música e pelo artista.',
    'step 6': 'Use o Reczt offline',
    'step6_desc': 'Se você perder a conexão com a internet, o Reczt pode salvar sua gravação e processá-la quando a conexão voltar.',
    'explore_more': 'Explore mais',
    'step 7': 'Explore seu histórico do Reczt',
    'step7_desc': 'Esqueceu quais músicas você cantou? Reveja músicas anteriores e clipes de áudio ou transforme seu Histórico em uma playlist no seu app de música preferido.',
    'step 8': 'Confira seus Analytics',
    'step8_desc': 'Acesse a página Analytics pela tela inicial para explorar sua playlist recomendada, gêneros mais cantados, artista principal, sequência diária, gráfico de emoções e mapa Acoustic Memory.',
    'step 9': 'Compartilhe com QuickShare',
    'step9_desc': 'Use o QuickShare nas páginas Analytics e Histórico para compartilhar músicas individuais ou toda a sua página Analytics nas suas plataformas favoritas.',
    'got it': 'Entendi!',
    'Outdoors': 'Ao ar livre',
    'no_valid_match': 'Nenhuma correspondência válida atingiu a pontuação de confiança dinâmica. Tente novamente!',
    'theme_title': 'Tema de cor do app',
    'theme_purple': 'Roxo profundo',
    'theme_blue': 'Azul oceano',
    'theme_emerald': 'Esmeralda',
    'theme_orange': 'Laranja pôr do sol',
    'auto_play_title': 'Reprodução automática',
    'share_text': 'Confira "{title}" de {artist}, encontrado sem usar as mãos com o Reczt!',
    'pending_queue_title': 'Pesquisas pendentes offline',
    'offline_saved': 'Sem internet. Salvo na fila offline!',
'analytics_title': 'Reczt Analytics',
      'streak_title': 'Sequência de canto',
      'days_active_suffix': 'Dias ativos',
      'top_artist': 'Principais artistas',
      'most_sung_genres': 'Gêneros mais cantados',
      'acoustic_map': 'Mapa de memória acústica',
      'vibe_match_playlist': 'Playlist de correspondência \n de vibe quinzenal',
      'playlist_countdown': 'Próxima atualização automática em 4 dias',
      'no_artist_data': 'Cante mais músicas para acompanhar os artistas!',
      'analyzing': 'Analisando humor...',
      'next_drop': 'Próxima atualização',
      'refreshing_soon': 'Atualizando em breve!',
      'open_in': 'Abrir no',
      'none': 'Nenhum',
      'sad': 'Triste',
    'happy': 'Feliz',
    'hype': 'Empolgado',
    'romantic': 'Romântico',
    'rock': 'Rock',
    'jazz': 'Jazz',
    'indie': 'Indie',
    'rap': 'Rap',
    'classical': 'Clássica',
    'reggae': 'Reggae',
    'r&b': 'R&B',
    'pop': 'Pop',
    'error_no_lyrics': 'Não foi possível reconhecer a letra. Tente cantar mais claramente!',
    'open_in_platform': 'Abrir no {platform}',
    'songs': 'músicas',
    'playlist_desc': 'Criado automaticamente via aplicativo Reczt',
    'auth_spotify': 'Autenticando com o Spotify...',
    'auth_failed': 'Autorização do Spotify cancelada ou falhou.',
    'creating_playlist': 'Criando playlist e buscando faixas...',
    'playlist_success': 'Sucesso! Playlist criada no Spotify.',
    'playlist_error': 'Não foi possível criar a playlist. Verifique a conexão com o Spotify.',
    'tap_to_play_preferred': 'Toque para reproduzir no seu aplicativo preferido',
    'play_singing_sample': 'Tocar amostra de canto',
    'share_card': 'Cartão de compartilhamento',
    'create_spotify_playlist': 'Criar playlist no Spotify',
    'create_apple_playlist': 'Criar playlist no Apple Music',
    'select_song_for_playlist': 'Selecione pelo menos uma música primeiro.',
    'apple_music_connecting': 'Conectando ao Apple Music...',
    'apple_playlist_creating': 'Criando playlist no Apple Music...',
    'apple_playlist_success': 'Sucesso! Playlist criada no Apple Music.',
    'apple_playlist_partial': 'Playlist criada no Apple Music: {added} adicionadas, {failed} não encontradas.',
    'apple_playlist_error': 'Não foi possível criar a playlist no Apple Music. Verifique o acesso ao Apple Music e tente novamente.',
    'analytics_share_text': 'Confira minhas estatísticas musicais no Reczt!',
    'calculating': 'Calculando...',
    'connection_failed': 'Falha na conexão',
    'error_empty_path': 'Erro: o caminho da gravação estava vazio.',
    'error_stopping': 'Erro ao parar a gravação',
    'live_pin_label': 'AO VIVO',
    'playlist_name': 'Histórico musical do Reczt',
    'quickshare_tooltip': 'Compartilhamento rápido',
    'server_error': 'Erro do servidor',
    'unknown_artist': 'Artista desconhecido',
    'opening_apple_search': 'Abrindo busca no Apple Music para',
    'processing_saved_recording': 'Processando gravação salva...',
    'queued_song_found': 'O Reczt encontrou sua música pendente!',
    'found_offline_badge': "Encontrada offline",
    'found_offline_detail': "Reconhecida da sua fila offline",
  
    'waiting_for_voice': 'Aguardando sua voz...',
    'signal_good': 'Bom sinal',
    'sing_louder': 'Cante um pouco mais alto',
    'top_guesses_title': 'Melhores opções',
    'top_guesses_subtitle': 'Não tenho certeza completa. Toque na música que você quis dizer.',
    'confidence': 'correspondência',
    'retry_search': 'Tentar novamente a última gravação',
    'search_timed_out': 'A busca demorou demais. Tente novamente.',
    'stop_recording': 'Parar gravação',
    'other': 'Outro',
  },
  'ja': {
    "clear_this_data": 'このデータを消去しますか？',
    "clear_this_data_confirm": '{section} のデータだけを消去しますか？その他の Reczt データは残ります。',
    "data_box_cleared": 'このデータカードを消去しました。',
    "emotions": '感情',
    "cleared": '消去済み',
    'clear_reczt_data': 'Recztデータを消去',
    'clear_reczt_data_desc': 'このデバイスの履歴、歌唱クリップ、分析、Acoustic Memoryのピン、オフライン待機中の録音を削除します。アプリ設定は保持されます。',
    'clear_reczt_data_confirm': 'このデバイスに保存されている曲の履歴、歌唱クリップ、分析、Acoustic Memoryの位置情報、オフライン待機中の録音を完全に削除します。言語、音楽アプリ、テーマ、Auto Play、法的設定は保持されます。この操作は元に戻せません。',
    'clear_data_action': 'データを消去',
    'clear_reczt_data_success': 'このデバイスからRecztデータを消去しました。',
    'clear_reczt_data_error': 'すべてのローカルデータを消去できませんでした。もう一度お試しください。',
    'legal_privacy': '法的情報とプライバシー',
    'privacy_policy': 'プライバシーポリシー',
    'terms_of_use': '利用規約',
    'open_source_licenses': 'オープンソースライセンス',
    'legal_notice_title': 'Recztへようこそ',
    'legal_notice_body': 'Recztを使用する前に、プライバシーポリシーと利用規約をご確認ください。「同意して続ける」をタップすると、利用規約に同意し、プライバシーポリシーを確認したものとみなされます。',
    'legal_accept': '同意して続ける',
    'legal_close': '閉じる',
    'view_online': 'オンラインで表示',
    'app_title': '楽曲識別アプリ',
    'where_are_you': 'どこにいますか？',
    'quiet_room': '静かな部屋',
    'loud_room': '騒がしい場所',
    'initial_status': '環境を選択し、マイクをタップするか、「Hey Siri, Activate Reczt」と話しかけてください。',
    'listening': '聞き取り中...',
    'searching': 'データベースを検索中...',
    'enhanced_search': "検索を続けています — 高精度認識を使用中…",
    'location_pin_permission': "アコースティックメモリーのピンを表示するには位置情報へのアクセスを許可してください。",
    'match_found': '曲が見つかりました！',
    'mic_denied': 'マイクのアクセス許可が拒否されました。',
    'settings_title': 'アプリ設定',
    'pref_music_app': 'お気に入りの音楽アプリ',    'pref_lang': '優先言語',
    'open_spotify': 'Spotifyで開く',
    'open_apple': 'Apple Musicで開く',
    'history_title': '検索履歴',
    'clear_history': '履歴を消去',
    'clear_history_confirm': 'すべての検索履歴を削除しますか？',
    'no_history': 'まだ検索された曲はありません！',
    'cancel': 'キャンセル',
    'save': '保存',
    'clear': '消去',
    'by': 'アーティスト:',
    'User Manual': '使い方',
    'getting_started': 'はじめに',
    'step 1': '設定を選ぶ',
    'step1_desc': 'Spotify または Apple Music、使用言語、Auto Play のオン／オフ、アプリのテーマを選択します。',
    'step 2': '環境を選ぶ',
    'step2_desc': '「静か」「騒がしい」「屋外」から選ぶと、Reczt が周囲の環境に合わせて認識を最適化します。',
    'step 3': '歌う・ハミングする・曲を再生する',
    'step3_desc': 'マイクをタップするか、Siri を使って認識を開始します。',
    'step 4': 'Reczt に最適な候補を探してもらう',
    'step4_desc': 'Reczt は複数の認識方法を使って曲を特定することがあります。結果があいまいな場合は、可能性の高い候補から選ぶよう求められることがあります。',
    'step 5': '結果を再生する',
    'step5_desc': 'Auto Play がオンの場合、Reczt は一致した曲を選択した音楽アプリで自動的に開きます。正確な曲を直接開けない場合は、曲名とアーティスト名の検索を開くことがあります。',
    'step 6': 'オフラインで Reczt を使う',
    'step6_desc': 'インターネット接続がなくなった場合、Reczt は録音を保存し、接続が戻ったときに処理できます。',
    'explore_more': 'さらに楽しむ',
    'step 7': 'Reczt の履歴を見る',
    'step7_desc': '歌った曲を忘れましたか？以前の曲や音声クリップを確認したり、履歴を選択した音楽アプリのプレイリストにしたりできます。',
    'step 8': 'Analytics をチェックする',
    'step8_desc': 'ホーム画面から Analytics ページを開くと、おすすめプレイリスト、よく歌うジャンル、トップアーティスト、連続利用日数、感情の円グラフ、Acoustic Memory マップを確認できます。',
    'step 9': 'QuickShare で共有する',
    'step9_desc': 'Analytics ページと履歴ページの QuickShare を使って、個別の曲や Analytics ページ全体をお気に入りのプラットフォームで共有できます。',
    'got it': '了解しました！',
    'Outdoors': '屋外',
    'no_valid_match': '有効な一致が動的信頼スコアを満たしませんでした。もう一度お試しください！',
    'theme_title': 'アプリのカラーテーマ',
    'theme_purple': 'ディープパープル',
    'theme_blue': 'オーシャンブルー',
    'theme_emerald': 'エメラルド',
    'theme_orange': 'サンセットオレンジ',
    'auto_play_title': '自動再生',
    'share_text': 'Recztを使ってハンズフリーで見つけた「{title}」by {artist}をチェックしてください！',
    'pending_queue_title': '保留中のオフライン検索',
    'offline_saved': 'インターネットがありません。オフラインキューに保存されました！',
    'analytics_title': 'レックツ・アナリティクス',
      'streak_title': '歌唱連続記録',
      'days_active_suffix': 'アクティブ日数',
      'top_artist': 'トップアーティスト',
      'most_sung_genres': '最も歌われたジャンル',
      'acoustic_map': '音響メモリーマップ',
      'vibe_match_playlist': '隔週のバイブマッチプレイリスト',
      'playlist_countdown': '4日後に次の自動更新',
      'no_artist_data': 'もっと歌ってトップアーティストを表示しよう！',
      'analyzing': '気分を分析中...',
      'next_drop': '次の更新',
      'refreshing_soon': 'もうすぐ更新！',
      'open_in': 'で開く',
      'none': 'なし',
      'sad': '悲しい',
    'happy': '嬉しい',
    'hype': 'ハイテンション',
    'romantic': 'ロマンチック',
    'rock': 'ロック',
    'jazz': 'ジャズ',
    'indie': 'インディー',
    'rap': 'ラップ',
    'classical': 'クラシック',
    'reggae': 'レゲエ',
    'r&b': 'R&B',
    'pop': 'ポップ',
    'error_no_lyrics': '歌詞を認識できませんでした。もう少しはっきりと歌ってみてください！',
    'open_in_platform': '{platform} で開く',
    'songs': '曲',
    'playlist_desc': 'Recztアプリで自動作成',
    'auth_spotify': 'Spotifyで認証中...',
    'auth_failed': 'Spotifyの認証がキャンセルまたは失敗しました。',
    'creating_playlist': 'プレイリストを作成して曲を検索中...',
    'playlist_success': '成功！Spotifyにプレイリストを作成しました。',
    'playlist_error': 'プレイリストを作成できませんでした。Spotifyが接続されているか確認してください。',
    'tap_to_play_preferred': 'タップしてお気に入りのアプリで再生',
    'play_singing_sample': '歌唱サンプルを再生',
    'quickshare': 'クイックシェア',
    'share_card': 'シェアカード',
    'create_spotify_playlist': 'Spotifyプレイリストを作成',
    'create_apple_playlist': 'Apple Musicプレイリストを作成',
    'select_song_for_playlist': 'まず1曲以上選択してください。',
    'apple_music_connecting': 'Apple Musicに接続しています...',
    'apple_playlist_creating': 'Apple Musicプレイリストを作成しています...',
    'apple_playlist_success': '成功しました！Apple Musicにプレイリストを作成しました。',
    'apple_playlist_partial': 'Apple Musicにプレイリストを作成しました：{added}曲を追加、{failed}曲は見つかりませんでした。',
    'apple_playlist_error': 'Apple Musicプレイリストを作成できませんでした。Apple Musicへのアクセスを確認して、もう一度お試しください。',
    'analytics_share_text': 'Recztで自分の音楽統計をチェックしよう！',
    'calculating': '計算中...',
    'connection_failed': '接続に失敗しました',
    'error_empty_path': 'エラー：録音のパスが空でした。',
    'error_stopping': '録音の停止中にエラーが発生しました',
    'live_pin_label': 'ライブ',
    'playlist_name': 'Reczt 音楽履歴',
    'quickshare_tooltip': 'クイックシェア',
    'server_error': 'サーバーエラー',
    'unknown_artist': '不明なアーティスト',
    'opening_apple_search': 'Apple Musicで検索を開いています：',
    'processing_saved_recording': '保存された録音を処理中...',
    'queued_song_found': 'Recztがキューに入っていた曲を見つけました！',
    'found_offline_badge': "オフラインで検出",
    'found_offline_detail': "オフラインキューから認識されました",
  
    'waiting_for_voice': '声を待っています…',
    'signal_good': '良い音量です',
    'sing_louder': 'もう少し大きな声で歌ってください',
    'top_guesses_title': '候補',
    'top_guesses_subtitle': '完全には特定できませんでした。該当する曲をタップしてください。',
    'confidence': '一致',
    'retry_search': '最後の録音を再検索',
    'search_timed_out': '検索に時間がかかりすぎました。もう一度お試しください。',
    'stop_recording': '録音を停止',
    'other': 'その他',
  },
  'ko': {
    "clear_this_data": '이 데이터를 지울까요?',
    "clear_this_data_confirm": '{section} 데이터만 지울까요? 다른 Reczt 데이터는 그대로 유지됩니다.',
    "data_box_cleared": '이 데이터 카드가 지워졌습니다.',
    "emotions": '감정',
    "cleared": '지움',
    'clear_reczt_data': 'Reczt 데이터 지우기',
    'clear_reczt_data_desc': '이 기기의 기록, 노래 클립, 분석, Acoustic Memory 핀 및 대기 중인 오프라인 녹음을 삭제합니다. 앱 환경설정은 유지됩니다.',
    'clear_reczt_data_confirm': '이 기기에 저장된 노래 기록, 노래 클립, 분석, Acoustic Memory 위치 및 대기 중인 오프라인 녹음을 영구적으로 삭제합니다. 언어, 음악 앱, 테마, Auto Play 및 법적 환경설정은 유지됩니다. 이 작업은 취소할 수 없습니다.',
    'clear_data_action': '데이터 지우기',
    'clear_reczt_data_success': '이 기기에서 Reczt 데이터를 지웠습니다.',
    'clear_reczt_data_error': 'Reczt가 모든 로컬 데이터를 지우지 못했습니다. 다시 시도해 주세요.',
    'legal_privacy': '법률 및 개인정보 보호',
    'privacy_policy': '개인정보 처리방침',
    'terms_of_use': '이용약관',
    'open_source_licenses': '오픈 소스 라이선스',
    'legal_notice_title': 'Reczt에 오신 것을 환영합니다',
    'legal_notice_body': 'Reczt를 사용하기 전에 개인정보 처리방침과 이용약관을 확인해 주세요. 동의하고 계속을 누르면 이용약관에 동의하고 개인정보 처리방침을 확인한 것으로 간주됩니다.',
    'legal_accept': '동의하고 계속',
    'legal_close': '닫기',
    'view_online': '온라인에서 보기',
    'app_title': '음악 검색 식별기',
    'where_are_you': '어디에 계신가요?',
    'quiet_room': '조용한 방',
    'loud_room': '시끄러운 장소',
    'initial_status': '환경을 선택한 뒤 마이크를 탭하거나 "Hey Siri, Activate Reczt"라고 말하세요!',
    'listening': '듣는 중...',
    'searching': '데이터베이스 검색 중...',
    'enhanced_search': "계속 검색 중 — 고급 인식 엔진 사용 중…",
    'location_pin_permission': "어쿠스틱 메모리 핀을 표시하려면 위치 접근을 허용해 주세요.",
    'match_found': '곡을 찾았습니다!',
    'mic_denied': '마이크 권한이 거부되었습니다.',
    'settings_title': '앱 설정',
    'pref_music_app': '선호하는 음악 앱',    'pref_lang': '선호하는 언어',
    'open_spotify': 'Spotify에서 열기',
    'open_apple': 'Apple Music에서 열기',
    'history_title': '검색 기록',
    'clear_history': '기록 삭제',
    'clear_history_confirm': '모든 검색 기록을 삭제하시겠습니까?',
    'no_history': '아직 검색한 노래가 없습니다!',
    'cancel': '취소',
    'save': '저장',
    'clear': '삭제',
    'by': '아티스트:',
    'User Manual': '사용 방법',
    'getting_started': '시작하기',
    'step 1': '환경설정 선택',
    'step1_desc': 'Spotify 또는 Apple Music, 선호 언어, Auto Play 켜기/끄기, 앱 테마를 선택하세요.',
    'step 2': '주변 환경 선택',
    'step2_desc': '조용함, 시끄러움 또는 야외를 선택하면 Reczt가 주변 환경에 맞게 인식을 최적화하는 데 도움이 됩니다.',
    'step 3': '노래하거나 흥얼거리거나 음악 재생',
    'step3_desc': '마이크를 탭하거나 Siri를 사용해 인식을 시작하세요.',
    'step 4': 'Reczt가 가장 적합한 결과 찾기',
    'step4_desc': 'Reczt는 곡을 식별하기 위해 여러 인식 방법을 사용할 수 있습니다. 결과가 모호하면 가장 가능성이 높은 후보 중에서 선택하도록 요청할 수 있습니다.',
    'step 5': '결과 재생',
    'step5_desc': 'Auto Play가 켜져 있으면 Reczt가 일치한 곡을 선호하는 음악 앱에서 자동으로 엽니다. 정확한 트랙을 직접 열 수 없으면 곡 제목과 아티스트 검색을 대신 열 수 있습니다.',
    'step 6': '오프라인에서 Reczt 사용',
    'step6_desc': '인터넷 연결이 끊기면 Reczt가 녹음을 저장하고 연결이 돌아왔을 때 처리할 수 있습니다.',
    'explore_more': '더 둘러보기',
    'step 7': 'Reczt 기록 살펴보기',
    'step7_desc': '어떤 노래를 불렀는지 잊었나요? 이전 곡과 오디오 클립을 확인하거나 기록을 선호하는 음악 앱의 플레이리스트로 만들 수 있습니다.',
    'step 8': 'Analytics 확인',
    'step8_desc': '홈 화면에서 Analytics 페이지를 열어 추천 플레이리스트, 가장 많이 부른 장르, 최다 아티스트, 일일 연속 기록, 감정 원형 차트, Acoustic Memory 지도를 확인하세요.',
    'step 9': 'QuickShare로 공유',
    'step9_desc': 'Analytics 및 기록 페이지의 QuickShare를 사용해 개별 곡이나 전체 Analytics 페이지를 즐겨 쓰는 플랫폼에 공유하세요.',
    'got it': '알겠습니다!',
    'Outdoors': '야외',
    'no_valid_match': '유효한 일치 항목이 동적 신뢰 점수를 충족하지 못했습니다. 다시 시도하세요!',
    'theme_title': '앱 색상 테마',
    'theme_purple': '딥 퍼플',
    'theme_blue': '오션 블루',
    'theme_emerald': '에메랄드',
    'theme_orange': '선셋 오렌지',
    'auto_play_title': '자동 재생',
    'share_text': 'Reczt를 사용하여 핸즈프리로 찾은 "{title}" by {artist}를 확인하세요!',
    'pending_queue_title': '보류 중인 오프라인 검색',
    'offline_saved': '인터넷 없음. 오프라인 대기열에 저장됨!',
'analytics_title': 'Reczt 분석 및 분위기',
      'streak_title': '노래 연속 기록',
      'days_active_suffix': '활동 일수',
      'top_artist': '최고 아티스트',
      'most_sung_genres': '가장 많이 부른 장르',
      'acoustic_map': '음향 메모리 맵',
      'acoustic_map_desc': '🗺️ 인식된 노래 위치에 핀이 배치되었습니다',
      'vibe_match_playlist': '격주 분위기 매치 재생목록',
      'playlist_countdown': '4일 후 자동 업데이트',
      'no_artist_data': '더 많은 노래를 불러 아티스트를 추적하세요!',
      'analyzing': '분위기 분석 중...',
      'next_drop': '다음 업데이트',
      'refreshing_soon': '곧 갱신됩니다!',
      'open_in': '열기:',
      'none': '없음',
      'sad': '슬픈',
    'happy': '행복한',
    'hype': '신나는',
    'romantic': '로맨틱한',
    'rock': '록',
    'jazz': '재즈',
    'indie': '인디',
    'rap': '랩',
    'classical': '클래식',
    'reggae': '레게',
    'r&b': 'R&B',
    'pop': '팝',
    'error_no_lyrics': '가사를 인식할 수 없습니다. 더 명확하게 불러보세요!',
    'open_in_platform': '{platform}에서 열기',
    'songs': '곡',
    'playlist_desc': 'Reczt 앱에서 자동으로 생성됨',
    'auth_spotify': 'Spotify 인증 중...',
    'auth_failed': 'Spotify 인증이 취소되었거나 실패했습니다.',
    'creating_playlist': '재생목록 생성 및 트랙 검색 중...',
    'playlist_success': '성공! Spotify에 재생목록이 생성되었습니다.',
    'playlist_error': '재생목록을 생성할 수 없습니다. Spotify가 연결되어 있는지 확인하세요.',
    'tap_to_play_preferred': '선호하는 앱에서 재생하려면 탭하세요',
    'play_singing_sample': '노래 샘플 재생',
    'share_card': '공유 카드',
    'create_spotify_playlist': 'Spotify 재생목록 만들기',
    'create_apple_playlist': 'Apple Music 재생목록 만들기',
    'select_song_for_playlist': '먼저 노래를 하나 이상 선택하세요.',
    'apple_music_connecting': 'Apple Music에 연결 중...',
    'apple_playlist_creating': 'Apple Music 재생목록을 만드는 중...',
    'apple_playlist_success': '성공! Apple Music에 재생목록이 생성되었습니다.',
    'apple_playlist_partial': 'Apple Music에 재생목록이 생성되었습니다: {added}곡 추가, {failed}곡 찾지 못함.',
    'apple_playlist_error': 'Apple Music 재생목록을 만들 수 없습니다. Apple Music 접근 권한을 확인하고 다시 시도하세요.',
    'analytics_share_text': 'Reczt에서 내 음악 분석을 확인해보세요!',
    'calculating': '계산 중...',
    'connection_failed': '연결 실패',
    'error_empty_path': '오류: 녹음 경로가 비어 있습니다.',
    'error_stopping': '녹음 중지 중 오류 발생',
    'live_pin_label': '실시간',
    'playlist_name': 'Reczt 음악 기록',
    'quickshare_tooltip': '빠른 공유',
    'server_error': '서버 오류',
    'unknown_artist': '알 수 없는 아티스트',
    'opening_apple_search': 'Apple Music에서 검색 여는 중:',
    'processing_saved_recording': '저장된 녹음 처리 중...',
    'queued_song_found': 'Reczt가 대기열에 있던 노래를 찾았습니다!',
    'found_offline_badge': "오프라인에서 찾음",
    'found_offline_detail': "오프라인 대기열에서 인식됨",
  
    'waiting_for_voice': '목소리를 기다리는 중...',
    'signal_good': '신호가 좋아요',
    'sing_louder': '조금 더 크게 불러 주세요',
    'top_guesses_title': '추천 후보',
    'top_guesses_subtitle': '완전히 확신할 수 없어요. 원하던 곡을 눌러 주세요.',
    'confidence': '일치',
    'retry_search': '마지막 녹음 다시 검색',
    'search_timed_out': '검색 시간이 너무 오래 걸렸어요. 다시 시도해 주세요.',
    'stop_recording': '녹음 중지',
    'other': '기타',
  },
  'zh': {
    "clear_this_data": '清除这些数据？',
    "clear_this_data_confirm": '只清除 {section} 数据吗？其他 Reczt 数据将保留。',
    "data_box_cleared": '此数据卡已清除。',
    "emotions": '情绪',
    "cleared": '已清除',
    'clear_reczt_data': '清除 Reczt 数据',
    'clear_reczt_data_desc': '删除此设备上的历史记录、演唱片段、分析数据、Acoustic Memory 标记和排队的离线录音。应用偏好设置会保留。',
    'clear_reczt_data_confirm': '这将永久删除此设备上的歌曲历史记录、演唱片段、分析数据、Acoustic Memory 位置信息和排队的离线录音。语言、音乐应用、主题、Auto Play 和法律偏好设置会保留。此操作无法撤销。',
    'clear_data_action': '清除数据',
    'clear_reczt_data_success': '已从此设备清除 Reczt 数据。',
    'clear_reczt_data_error': 'Reczt 无法清除所有本地数据。请重试。',
    'legal_privacy': '法律与隐私',
    'privacy_policy': '隐私政策',
    'terms_of_use': '使用条款',
    'open_source_licenses': '开源许可证',
    'legal_notice_title': '欢迎使用 Reczt',
    'legal_notice_body': '使用 Reczt 前，请查看隐私政策和使用条款。点击“同意并继续”即表示你同意使用条款并知悉隐私政策。',
    'legal_accept': '同意并继续',
    'legal_close': '关闭',
    'view_online': '在线查看',
    'app_title': '歌曲识别器',
    'where_are_you': '你在哪里？',
    'quiet_room': '安静的房间',
    'loud_room': '吵闹的环境',
    'initial_status': '选择你的环境并点击麦克风，或者说：“嘿 Siri，激活 Reczt”！',
    'listening': '正在聆听...',
    'searching': '正在搜索数据库...',
    'enhanced_search': "仍在搜索 — 正在使用增强识别…",
    'location_pin_permission': "请允许位置访问，以显示声学记忆图钉。",
    'match_found': '找到歌曲！',
    'mic_denied': '麦克风权限被拒绝。',
    'settings_title': '应用设置',
    'pref_music_app': '首选音乐应用',    'pref_lang': '首选语言',
    'open_spotify': '在 Spotify 中打开',
    'open_apple': '在 Apple Music 中打开',
    'history_title': '搜索历史',
    'clear_history': '清除历史',
    'clear_history_confirm': '确定要删除所有搜索记录吗？',
    'no_history': '还没有搜索过歌曲！',
    'cancel': '取消',
    'save': '保存',
    'clear': '清除',
    'by': '歌手：',
    'User Manual': '使用方法',
    'getting_started': '开始使用',
    'step 1': '设置你的偏好',
    'step1_desc': '选择 Spotify 或 Apple Music、首选语言、开启或关闭 Auto Play，并选择应用主题。',
    'step 2': '选择你的环境',
    'step2_desc': '选择安静、嘈杂或户外，帮助 Reczt 根据周围环境优化识别。',
    'step 3': '唱歌、哼唱或播放歌曲',
    'step3_desc': '点击麦克风或使用 Siri 开始识别。',
    'step 4': '让 Reczt 找到最佳匹配',
    'step4_desc': 'Reczt 可能会使用多种识别方法来确定歌曲。如果结果存在歧义，Reczt 可能会让你在最可能的候选结果中进行选择。',
    'step 5': '播放结果',
    'step5_desc': '开启 Auto Play 后，Reczt 会自动在你首选的音乐应用中打开匹配结果。如果无法直接打开准确曲目，Reczt 可能会改为打开歌曲名和艺人名的搜索。',
    'step 6': '离线使用 Reczt',
    'step6_desc': '如果失去网络连接，Reczt 可以保存录音，并在网络恢复后进行处理。',
    'explore_more': '探索更多',
    'step 7': '查看 Reczt 历史记录',
    'step7_desc': '忘了自己唱过哪些歌？你可以查看之前的歌曲和音频片段，或将历史记录在首选音乐应用中制作成播放列表。',
    'step 8': '查看你的 Analytics',
    'step8_desc': '从主屏幕进入 Analytics 页面，查看推荐播放列表、最常演唱的流派、最常演唱的艺人、每日连续记录、情绪饼图和 Acoustic Memory 地图。',
    'step 9': '使用 QuickShare 分享',
    'step9_desc': '在 Analytics 和历史记录页面使用 QuickShare，将单首歌曲或整个 Analytics 页面分享到你喜欢的平台。',
    'got it': '明白了！',
    'Outdoors': '户外',
    'no_valid_match': '没有有效的匹配满足动态置信度分数。请再试一次！',
    'theme_title': '应用颜色主题',
    'theme_purple': '深紫色',
    'theme_blue': '海洋蓝',
    'theme_emerald': '绿宝石',
    'theme_orange': '日落橙',
    'auto_play_title': '自动播放',
    'share_text': '查看 "{title}" by {artist}, 使用 Reczt 无需动手即可找到！',
    'pending_queue_title': '待处理的离线搜索',
    'offline_saved': '没有网络。已保存到离线队列！',
'analytics_title': 'Reczt 分析与氛围',
      'streak_title': '歌唱连续记录',
      'days_active_suffix': '活跃天数',
      'top_artist': '顶尖歌手',
      'most_sung_genres': '最常唱的流派',
      'acoustic_map': '音响内存地图',
      'acoustic_map_desc': '🗺️ 为已识别的歌曲位置放置图钉',
      'vibe_match_playlist': '双周氛围匹配播放列表',
      'playlist_countdown': '4天后自动更新',
      'no_artist_data': '多唱几首歌来追踪热门艺人！',
      'analyzing': '正在分析心情...',
      'next_drop': '下次更新',
      'refreshing_soon': '即将刷新！',
      'open_in': '在以下打开',
      'none': '没有任何',
      'sad': '悲伤',
    'happy': '快乐',
    'hype': '嗨',
    'romantic': '浪漫',
    'rock': '摇滚',
    'jazz': '爵士',
    'indie': '独立',
    'rap': '说唱',
    'classical': '古典',
    'reggae': '雷鬼',
    'r&b': 'R&B',
    'pop': '流行',
    'error_no_lyrics': '无法识别歌词。尝试唱得更清晰一些！',
    'open_in_platform': '在以下打开 {platform}',
    'songs': '首歌',
    'playlist_desc': '通过 Reczt 应用自动创建',
    'auth_spotify': '正在通过 Spotify 验证...',
    'auth_failed': 'Spotify 授权已取消或失败。',
    'creating_playlist': '正在创建歌单并搜索歌曲...',
    'playlist_success': '成功！已在 Spotify 中创建歌单。',
    'playlist_error': '无法创建歌单。请确保已连接 Spotify。',
    'tap_to_play_preferred': '轻触在偏好应用中播放',
    'play_singing_sample': '播放演唱片段',
    'share_card': '分享卡片',
    'create_spotify_playlist': '创建 Spotify 歌单',
    'create_apple_playlist': '创建 Apple Music 歌单',
    'select_song_for_playlist': '请先至少选择一首歌曲。',
    'apple_music_connecting': '正在连接 Apple Music...',
    'apple_playlist_creating': '正在创建 Apple Music 歌单...',
    'apple_playlist_success': '成功！已在 Apple Music 中创建歌单。',
    'apple_playlist_partial': '已在 Apple Music 中创建歌单：添加 {added} 首，未找到 {failed} 首。',
    'apple_playlist_error': '无法创建 Apple Music 歌单。请检查 Apple Music 访问权限后重试。',
    'analytics_share_text': '快来看看我在 Reczt 上的音乐数据吧！',
    'calculating': '计算中...',
    'connection_failed': '连接失败',
    'error_empty_path': '错误：录音路径为空。',
    'error_stopping': '停止录音时出错',
    'live_pin_label': '实时',
    'playlist_name': 'Reczt 音乐历史',
    'quickshare_tooltip': '快速分享',
    'server_error': '服务器错误',
    'unknown_artist': '未知艺术家',
    'opening_apple_search': '正在打开 Apple Music 搜索：',
    'processing_saved_recording': '正在处理已保存的录音...',
    'queued_song_found': 'Reczt 已找到你排队等待的歌曲！',
    'found_offline_badge': "离线找到",
    'found_offline_detail': "从离线队列中识别",
  
    'waiting_for_voice': '正在等待你的声音…',
    'signal_good': '声音信号良好',
    'sing_louder': '请唱得再大声一点',
    'top_guesses_title': '最可能的歌曲',
    'top_guesses_subtitle': '我还不能完全确定。请点选你想找的歌曲。',
    'confidence': '匹配',
    'retry_search': '重试上次录音',
    'search_timed_out': '搜索时间过长，请重试。',
    'stop_recording': '停止录音',
    'other': '其他',
  },
  'hi': {
    "clear_this_data": 'यह डेटा साफ़ करें?',
    "clear_this_data_confirm": 'केवल {section} का डेटा साफ़ करें? आपका बाकी Reczt डेटा बना रहेगा।',
    "data_box_cleared": 'यह डेटा कार्ड साफ़ कर दिया गया।',
    "emotions": 'भावनाएँ',
    "cleared": 'साफ़ किया गया',
    'clear_reczt_data': 'Reczt डेटा साफ़ करें',
    'clear_reczt_data_desc': 'इस डिवाइस से सेव किया गया इतिहास, गाने के क्लिप, एनालिटिक्स, Acoustic Memory पिन और कतार में रखी ऑफ़लाइन रिकॉर्डिंग हटाता है। ऐप की प्राथमिकताएँ बनी रहती हैं।',
    'clear_reczt_data_confirm': 'यह इस डिवाइस से आपके सेव किए गए गानों का इतिहास, गाने के क्लिप, एनालिटिक्स, Acoustic Memory स्थान और कतार में रखी ऑफ़लाइन रिकॉर्डिंग स्थायी रूप से हटा देगा। भाषा, संगीत ऐप, थीम, Auto Play और कानूनी प्राथमिकताएँ बनी रहेंगी। इसे वापस नहीं किया जा सकता।',
    'clear_data_action': 'डेटा साफ़ करें',
    'clear_reczt_data_success': 'इस डिवाइस से Reczt डेटा साफ़ कर दिया गया है।',
    'clear_reczt_data_error': 'Reczt सभी स्थानीय डेटा साफ़ नहीं कर सका। कृपया फिर से प्रयास करें।',
    'legal_privacy': 'कानूनी और गोपनीयता',
    'privacy_policy': 'गोपनीयता नीति',
    'terms_of_use': 'उपयोग की शर्तें',
    'open_source_licenses': 'ओपन-सोर्स लाइसेंस',
    'legal_notice_title': 'Reczt में आपका स्वागत है',
    'legal_notice_body': 'Reczt का उपयोग करने से पहले गोपनीयता नीति और उपयोग की शर्तें देखें। सहमत हों और जारी रखें पर टैप करके आप शर्तों से सहमत होते हैं और गोपनीयता नीति को स्वीकार करते हैं।',
    'legal_accept': 'सहमत हों और जारी रखें',
    'legal_close': 'बंद करें',
    'view_online': 'ऑनलाइन देखें',
    'app_title': 'गाना पहचानें',
    'where_are_you': 'आप कहाँ हैं?',
    'quiet_room': 'शांत कमरा',
    'loud_room': 'शोर-शराबे वाली जगह',
    'initial_status': 'अपना एनवायरनमेंट चुनें और माइक पर टैप करें या "Hey Siri, Activate Reczt" कहें!',
    'listening': 'सुन रहा है...',
    'searching': 'डेटाबेस में खोज रहा है...',
    'enhanced_search': "खोज जारी है — उन्नत पहचान का उपयोग हो रहा है…",
    'location_pin_permission': "अकूस्टिक मेमोरी पिन दिखाने के लिए स्थान की अनुमति दें।",
    'match_found': 'गाना मिल गया!',
    'mic_denied': 'माइक अनुमति अस्वीकृत।',
    'settings_title': 'ऐप प्राथमिकताएं',
    'pref_music_app': 'पसंदीदा संगीत ऐप',    'pref_lang': 'पसंदीदा भाषा',
    'open_spotify': 'Spotify में खोलें',
    'open_apple': 'Apple Music में खोलें',
    'history_title': 'खोज इतिहास',
    'clear_history': 'इतिहास मिटाएं',
    'clear_history_confirm': 'क्या आप सभी खोज इतिहास को हटाना चाहते हैं?',
    'no_history': 'अभी तक कोई गाना नहीं खोजा गया!',
    'cancel': 'रद्द करें',
    'save': 'सहेजें',
    'clear': 'मिटाएं',
    'by': 'द्वारा',
    'User Manual': 'कैसे उपयोग करें',
    'getting_started': 'शुरू करें',
    'step 1': 'अपनी पसंद सेट करें',
    'step1_desc': 'Spotify या Apple Music, अपनी पसंदीदा भाषा, Auto Play चालू या बंद, और ऐप थीम चुनें।',
    'step 2': 'अपना वातावरण चुनें',
    'step2_desc': 'शांत, शोर वाला या बाहर चुनें ताकि Reczt आपके आसपास के माहौल के अनुसार पहचान को बेहतर बना सके।',
    'step 3': 'गाएँ, गुनगुनाएँ या कोई गाना चलाएँ',
    'step3_desc': 'पहचान शुरू करने के लिए माइक्रोफ़ोन पर टैप करें या Siri का उपयोग करें।',
    'step 4': 'Reczt को सबसे अच्छा मिलान खोजने दें',
    'step4_desc': 'Reczt आपके गाने की पहचान के लिए कई पहचान विधियों का उपयोग कर सकता है। यदि परिणाम अस्पष्ट हो, तो Reczt आपसे सबसे संभावित मिलानों में से चुनने को कह सकता है।',
    'step 5': 'परिणाम चलाएँ',
    'step5_desc': 'Auto Play चालू होने पर Reczt मिलान को आपके पसंदीदा संगीत ऐप में अपने-आप खोलता है। यदि सटीक ट्रैक सीधे नहीं खुल सकता, तो वह गाने और कलाकार की खोज खोल सकता है।',
    'step 6': 'Reczt को ऑफ़लाइन उपयोग करें',
    'step6_desc': 'यदि इंटरनेट कनेक्शन चला जाए, तो Reczt आपकी रिकॉर्डिंग सहेज सकता है और कनेक्शन वापस आने पर उसे प्रोसेस कर सकता है।',
    'explore_more': 'और जानें',
    'step 7': 'अपना Reczt इतिहास देखें',
    'step7_desc': 'भूल गए कि आपने कौन से गाने गाए थे? पिछले गाने और ऑडियो क्लिप देखें, या अपने इतिहास को अपने पसंदीदा संगीत ऐप में प्लेलिस्ट में बदलें।',
    'step 8': 'अपने Analytics देखें',
    'step8_desc': 'होम स्क्रीन से Analytics पेज पर जाएँ और अपनी सुझाई गई प्लेलिस्ट, सबसे अधिक गाए गए जॉनर, शीर्ष कलाकार, दैनिक स्ट्रीक, भावना पाई चार्ट और Acoustic Memory मैप देखें।',
    'step 9': 'QuickShare से साझा करें',
    'step9_desc': 'Analytics और History पेजों से QuickShare का उपयोग करके अलग-अलग गाने या अपना पूरा Analytics पेज अपनी पसंदीदा प्लेटफ़ॉर्म पर साझा करें।',
    'got it': 'समझ गया!',
    'Outdoors': 'बाहर',
    'no_valid_match': 'कोई मान्य मिलान गतिशील विश्वास स्कोर को पूरा नहीं करता है। फिर से प्रयास करें!',
    'theme_title': 'ऐप रंग थीम',
    'theme_purple': 'डीप पर्पल',
    'theme_blue': 'ओशन ब्लू',
    'theme_emerald': 'एमराल्ड',
    'theme_orange': 'सनसेट ऑरेंज',
    'auto_play_title': 'स्वचालित चलना',
    'share_text': 'Reczt का उपयोग करके हाथों से मुक्त रूप से पाया गया "{title}" by {artist} देखें!',
    'pending_queue_title': 'लंबित ऑफ़लाइन खोज',
    'offline_saved': 'कोई इंटरनेट नहीं। ऑफ़लाइन कतार में सहेजा गया!',
'analytics_title': 'Reczt एनालिटिक्स',
      'streak_title': 'लगातार गाने का सिलसिला',
      'days_active_suffix': 'सक्रिय दिन',
      'top_artist': 'टॉप आर्टिस्ट',
      'most_sung_genres': 'सबसे ज़्यादा गाई जाने वाली शैलियाँ',
      'acoustic_map': 'ध्वनि-संबंधी स्मृति मानचित्र',
      'acoustic_map_desc': '🗺️ पहचाने गए गाने के स्थानों के लिए पिन लगाए गए',
      'vibe_match_playlist': 'हर दो हफ़्ते में आने वाली \n वाइब मैच प्लेलिस्ट',
      'playlist_countdown': '4 दिनों में अगला ऑटो-अपडेट',
      'no_artist_data': 'शीर्ष कलाकारों को ट्रैक करने के लिए और गाने गाएं!',
      'analyzing': 'मूड का विश्लेषण हो रहा है...',
      'next_drop': 'अगला अपडेट',
      'refreshing_soon': 'जल्द रीफ्रेश हो रहा है!',
      'open_in': 'में खोलें',
      'none': 'कोई नहीं',
      'sad': 'उदास',
    'happy': 'खुश',
    'hype': 'उत्साहित',
    'romantic': 'रोमान्टिक',
    'rock': 'रॉक',
    'jazz': 'जैज़',
    'indie': 'इंडी',
    'rap': 'रैप',
    'classical': 'क्लासिकल',
    'reggae': 'रेगे',
    'r&b': 'आर एंड बी',
    'pop': 'पॉप',
    'error_no_lyrics': 'बोल पहचाने नहीं जा सके। और स्पष्ट गाने का प्रयास करें!',
    'open_in_platform': '{platform} में खोलें',
    'songs': 'गाने',
    'playlist_desc': 'Reczt ऐप के माध्यम से स्वचालित रूप से बनाया गया',
    'auth_spotify': 'Spotify के साथ प्रमाणीकरण हो रहा है...',
    'auth_failed': 'Spotify प्रमाणीकरण रद्द कर दिया गया या विफल रहा।',
    'creating_playlist': 'प्लेलिस्ट बनाई जा रही है और गाने खोजे जा रहे हैं...',
    'playlist_success': 'सफलता! Spotify में प्लेलिस्ट बनाई गई।',
    'playlist_error': 'प्लेलिस्ट नहीं बन सकी। सुनिश्चित करें कि Spotify कनेक्ट है।',
    'tap_to_play_preferred': 'अपने पसंदीदा ऐप में चलाने के लिए टैप करें',
    'play_singing_sample': 'गायन नमूना चलाएं',
    'share_card': 'शेयर कार्ड',
    'create_spotify_playlist': 'Spotify प्लेलिस्ट बनाएं',
    'create_apple_playlist': 'Apple Music प्लेलिस्ट बनाएं',
    'select_song_for_playlist': 'पहले कम से कम एक गाना चुनें।',
    'apple_music_connecting': 'Apple Music से कनेक्ट हो रहा है...',
    'apple_playlist_creating': 'Apple Music प्लेलिस्ट बनाई जा रही है...',
    'apple_playlist_success': 'सफल! Apple Music में प्लेलिस्ट बन गई।',
    'apple_playlist_partial': 'Apple Music में प्लेलिस्ट बन गई: {added} जोड़े गए, {failed} नहीं मिले।',
    'apple_playlist_error': 'Apple Music प्लेलिस्ट नहीं बन सकी। Apple Music की अनुमति जाँचें और फिर कोशिश करें।',
    'analytics_share_text': 'Reczt पर मेरे संगीत आँकड़े देखें!',
    'calculating': 'गणना हो रही है...',
    'connection_failed': 'कनेक्ट करने में विफल',
    'error_empty_path': 'त्रुटि: रिकॉर्डिंग पथ खाली था।',
    'error_stopping': 'रिकॉर्डिंग रोकने में त्रुटि',
    'live_pin_label': 'लाइव',
    'playlist_name': 'Reczt संगीत इतिहास',
    'quickshare_tooltip': 'क्विकशेयर',
    'server_error': 'सर्वर त्रुटि',
    'unknown_artist': 'अज्ञात कलाकार',
    'opening_apple_search': 'इसके लिए Apple Music खोज खोली जा रही है:',
    'processing_saved_recording': 'सहेजी गई रिकॉर्डिंग को संसाधित किया जा रहा है...',
    'queued_song_found': 'Reczt ने आपके कतार में रखे गाने को ढूंढ लिया है!',
    'found_offline_badge': "ऑफ़लाइन मिला",
    'found_offline_detail': "आपकी ऑफ़लाइन कतार से पहचाना गया",
  
    'waiting_for_voice': 'आपकी आवाज़ का इंतज़ार है...',
    'signal_good': 'अच्छा सिग्नल',
    'sing_louder': 'थोड़ा और तेज़ गाएँ',
    'top_guesses_title': 'सबसे संभावित विकल्प',
    'top_guesses_subtitle': 'मैं पूरी तरह निश्चित नहीं हूँ। अपनी गीत वाली पसंद पर टैप करें।',
    'confidence': 'मिलान',
    'retry_search': 'पिछली रिकॉर्डिंग फिर खोजें',
    'search_timed_out': 'खोज में बहुत समय लग गया। कृपया फिर कोशिश करें।',
    'stop_recording': 'रिकॉर्डिंग रोकें',
    'other': 'अन्य',
  },
  'ru': {
    "clear_this_data": 'Очистить эти данные?',
    "clear_this_data_confirm": 'Очистить только данные «{section}»? Остальные данные Reczt сохранятся.',
    "data_box_cleared": 'Данные этой карточки очищены.',
    "emotions": 'Эмоции',
    "cleared": 'Очищено',
    'clear_reczt_data': 'Очистить данные Reczt',
    'clear_reczt_data_desc': 'Удаляет с устройства историю, записи пения, аналитику, метки Acoustic Memory и ожидающие офлайн-записи. Настройки приложения сохраняются.',
    'clear_reczt_data_confirm': 'Это навсегда удалит с устройства историю песен, записи пения, аналитику, местоположения Acoustic Memory и ожидающие офлайн-записи. Язык, музыкальное приложение, тема, Auto Play и юридические настройки сохранятся. Отменить это действие нельзя.',
    'clear_data_action': 'Очистить данные',
    'clear_reczt_data_success': 'Данные Reczt удалены с этого устройства.',
    'clear_reczt_data_error': 'Reczt не удалось удалить все локальные данные. Повторите попытку.',
    'legal_privacy': 'Правовая информация и конфиденциальность',
    'privacy_policy': 'Политика конфиденциальности',
    'terms_of_use': 'Условия использования',
    'open_source_licenses': 'Лицензии открытого ПО',
    'legal_notice_title': 'Добро пожаловать в Reczt',
    'legal_notice_body': 'Перед использованием Reczt ознакомьтесь с Политикой конфиденциальности и Условиями использования. Нажимая «Согласиться и продолжить», вы принимаете Условия и подтверждаете ознакомление с Политикой конфиденциальности.',
    'legal_accept': 'Согласиться и продолжить',
    'legal_close': 'Закрыть',
    'view_online': 'Открыть онлайн',
    'app_title': 'Распознавание Музыки',
    'where_are_you': 'Где вы находитесь?',
    'quiet_room': 'Тихая комната',
    'loud_room': 'Шумное помещение',
    'initial_status': 'Выберите обстановку и нажмите на микрофон или скажите: "Hey Siri, Activate Reczt"!',
    'listening': 'Слушаю...',
    'searching': 'Поиск в базе данных...',
    'enhanced_search': "Поиск продолжается — используется расширенное распознавание…",
    'location_pin_permission': "Разрешите доступ к геопозиции, чтобы добавлять метки Acoustic Memory.",
    'match_found': 'Песня найдена!',
    'mic_denied': 'Доступ к микрофону запрещен.',
    'settings_title': 'Настройки приложения',
    'pref_music_app': 'Предпочитаемое музыкальное приложение',    'pref_lang': 'Предпочитаемый язык',
    'open_spotify': 'Открыть в Spotify',
    'open_apple': 'Открыть в Apple Music',
    'history_title': 'История поиска',
    'clear_history': 'Очистить историю',
    'clear_history_confirm': 'Вы уверены, что хотите удалить историю поиска?',
    'no_history': 'Вы еще не искали песни!',
    'cancel': 'Отмена',
    'save': 'Сохранить',
    'clear': 'Очистить',
    'by': 'исполнитель',
    'User Manual': 'Как использовать',
    'getting_started': 'Начало работы',
    'step 1': 'Настройте предпочтения',
    'step1_desc': 'Выберите Spotify или Apple Music, предпочитаемый язык, включите или выключите Auto Play и выберите тему приложения.',
    'step 2': 'Выберите окружение',
    'step2_desc': 'Выберите Тихо, Шумно или На улице, чтобы Reczt мог оптимизировать распознавание под ваше окружение.',
    'step 3': 'Пойте, напевайте или включите песню',
    'step3_desc': 'Нажмите на микрофон или используйте Siri, чтобы начать распознавание.',
    'step 4': 'Позвольте Reczt найти лучший вариант',
    'step4_desc': 'Reczt может использовать несколько методов распознавания, чтобы определить песню. Если результат неоднозначен, Reczt может попросить выбрать один из наиболее вероятных вариантов.',
    'step 5': 'Воспроизведите результат',
    'step5_desc': 'При включённом Auto Play Reczt автоматически открывает найденную песню в выбранном музыкальном приложении. Если точный трек нельзя открыть напрямую, может открыться поиск по названию песни и исполнителю.',
    'step 6': 'Используйте Reczt офлайн',
    'step6_desc': 'Если интернет-соединение пропадёт, Reczt может сохранить запись и обработать её после восстановления подключения.',
    'explore_more': 'Узнайте больше',
    'step 7': 'Изучите историю Reczt',
    'step7_desc': 'Забыли, какие песни вы пели? Просматривайте предыдущие песни и аудиоклипы или превратите Историю в плейлист в выбранном музыкальном приложении.',
    'step 8': 'Посмотрите свои Analytics',
    'step8_desc': 'Откройте страницу Analytics с главного экрана, чтобы увидеть рекомендованный плейлист, самые исполняемые жанры, топ-исполнителя, ежедневную серию, круговую диаграмму эмоций и карту Acoustic Memory.',
    'step 9': 'Делитесь через QuickShare',
    'step9_desc': 'Используйте QuickShare на страницах Analytics и История, чтобы делиться отдельными песнями или всей страницей Analytics на любимых платформах.',
    'got it': 'С понятием!',
    'Outdoors': 'На улице',
    'no_valid_match': 'Ни одно совпадение не достигло динамического уровня достоверности. Попробуйте еще раз!',
    'theme_title': 'Цветовая тема приложения',
    'theme_purple': 'Темно-фиолетовый',
    'theme_blue': 'Океанский синий',
    'theme_emerald': 'Изумруд',
    'theme_orange': 'Закатный оранжевый',
    'auto_play_title': 'Автовоспроизведение',
    'share_text': 'Посмотрите "{title}" от {artist}, найденный без рук с помощью Reczt!',
    'pending_queue_title': 'Ожидающие оффлайн-поиски',
    'offline_saved': 'Нет интернета. Сохранено в оффлайн-очереди!',
'analytics_title': 'Reczt Аналитика',
      'streak_title': 'Стикер пения',
      'days_active_suffix': 'Дней активности',
      'top_artist': 'Лучшие исполнители',
      'most_sung_genres': 'Наиболее популярные жанры',
      'acoustic_map': 'Карта звуковой памяти',
      'acoustic_map_desc': '🗺️ Метки для распознанных мест песен',
      'vibe_match_playlist': 'Би-недельный плейлист \n вибров совпадений',
      'playlist_countdown': 'Следующее автообновление через 4 дня',
      'no_artist_data': 'Пойте больше песен, чтобы отслеживать артистов!',
      'analyzing': 'Анализ настроения...',
      'next_drop': 'Следующий выпуск',
      'refreshing_soon': 'Скоро обновление!',
      'open_in': 'Открыть в',
      'none': 'Никто',
      'sad': 'Грустный',
    'happy': 'Счастливый',
    'hype': 'Взволнованный',
    'romantic': 'Романтичный',
    'rock': 'Рок',
    'jazz': 'Джаз',
    'indie': 'Инди',
    'rap': 'Рэп',
    'classical': 'Классика',
    'reggae': 'Регги',
    'r&b': 'R&B',
    'pop': 'Поп',
    'error_no_lyrics': 'Не удалось распознать текст песни. Попробуйте петь четче!',
    'open_in_platform': 'Открыть в {platform}',
    'songs': 'песен',
    'playlist_desc': 'Создано автоматически через приложение Reczt',
    'auth_spotify': 'Авторизация в Spotify...',
    'auth_failed': 'Авторизация Spotify отменена или не удалась.',
    'creating_playlist': 'Создание плейлиста и поиск треков...',
    'playlist_success': 'Успех! Плейлист создан в Spotify.',
    'playlist_error': 'Не удалось создать плейлист. Убедитесь, что Spotify подключен.',
    'tap_to_play_preferred': 'Нажмите для воспроизведения в предпочитаемом приложении',
    'play_singing_sample': 'Воспроизвести образец пения',
    'share_card': 'Карточка шеринга',
    'create_spotify_playlist': 'Создать плейлист Spotify',
    'create_apple_playlist': 'Создать плейлист Apple Music',
    'select_song_for_playlist': 'Сначала выберите хотя бы одну песню.',
    'apple_music_connecting': 'Подключение к Apple Music...',
    'apple_playlist_creating': 'Создание плейлиста Apple Music...',
    'apple_playlist_success': 'Готово! Плейлист создан в Apple Music.',
    'apple_playlist_partial': 'Плейлист создан в Apple Music: добавлено {added}, не найдено {failed}.',
    'apple_playlist_error': 'Не удалось создать плейлист Apple Music. Проверьте доступ к Apple Music и повторите попытку.',
    'analytics_share_text': 'Посмотри мою музыкальную статистику в Reczt!',
    'calculating': 'Вычисление...',
    'connection_failed': 'Не удалось подключиться',
    'error_empty_path': 'Ошибка: путь к записи пуст.',
    'error_stopping': 'Ошибка при остановке записи',
    'live_pin_label': 'СЕЙЧАС',
    'playlist_name': 'История музыки Reczt',
    'quickshare_tooltip': 'Быстрый доступ к обмену',
    'server_error': 'Ошибка сервера',
    'unknown_artist': 'Неизвестный исполнитель',
    'opening_apple_search': 'Открытие поиска в Apple Music для',
    'processing_saved_recording': 'Обработка сохранённой записи...',
    'queued_song_found': 'Reczt нашёл вашу песню из очереди!',
    'found_offline_badge': "Найдено офлайн",
    'found_offline_detail': "Распознано из офлайн-очереди",
  
    'waiting_for_voice': 'Жду ваш голос...',
    'signal_good': 'Хороший сигнал',
    'sing_louder': 'Пойте немного громче',
    'top_guesses_title': 'Лучшие варианты',
    'top_guesses_subtitle': 'Я не совсем уверен. Нажмите на нужную песню.',
    'confidence': 'совпадение',
    'retry_search': 'Повторить поиск последней записи',
    'search_timed_out': 'Поиск занял слишком много времени. Попробуйте снова.',
    'stop_recording': 'Остановить запись',
    'other': 'Другое',
  },
  'tr': {
    "clear_this_data": 'Bu veriler temizlensin mi?',
    "clear_this_data_confirm": 'Yalnızca {section} verileri temizlensin mi? Diğer Reczt verileriniz korunur.',
    "data_box_cleared": 'Bu veri kartı temizlendi.',
    "emotions": 'Duygular',
    "cleared": 'Temizlendi',
    'clear_reczt_data': 'Reczt Verilerini Temizle',
    'clear_reczt_data_desc': 'Bu cihazdaki geçmişi, şarkı söyleme kliplerini, analizleri, Acoustic Memory pinlerini ve sıradaki çevrimdışı kayıtları siler. Uygulama tercihleri korunur.',
    'clear_reczt_data_confirm': 'Bu işlem, bu cihazdaki şarkı geçmişinizi, şarkı söyleme kliplerinizi, analizlerinizi, Acoustic Memory konumlarınızı ve sıradaki çevrimdışı kayıtları kalıcı olarak siler. Dil, müzik uygulaması, tema, Auto Play ve yasal tercihler korunur. Bu işlem geri alınamaz.',
    'clear_data_action': 'Verileri Temizle',
    'clear_reczt_data_success': 'Reczt verileri bu cihazdan temizlendi.',
    'clear_reczt_data_error': 'Reczt tüm yerel verileri temizleyemedi. Lütfen tekrar deneyin.',
    'legal_privacy': 'Yasal ve Gizlilik',
    'privacy_policy': 'Gizlilik Politikası',
    'terms_of_use': 'Kullanım Koşulları',
    'open_source_licenses': 'Açık Kaynak Lisansları',
    'legal_notice_title': 'Reczt’e Hoş Geldiniz',
    'legal_notice_body': 'Reczt’i kullanmadan önce Gizlilik Politikası ve Kullanım Koşullarını inceleyin. Kabul Et ve Devam Et’e dokunarak Koşulları kabul eder ve Gizlilik Politikasını onaylarsınız.',
    'legal_accept': 'Kabul Et ve Devam Et',
    'legal_close': 'Kapat',
    'view_online': 'Çevrimiçi Görüntüle',
    'app_title': 'Şarkı Tanıma',
    'where_are_you': 'Neredesiniz?',
    'quiet_room': 'Sessiz bir oda',
    'loud_room': 'Gürültülü bir ortam',
    'initial_status': 'Ortamınızı seçin ve mikrofona dokunun ya da "Hey Siri, Reczt\'i etkinleştir" deyin!',
    'listening': 'Dinleniyor...',
    'searching': 'Veritabanı aranıyor...',
    'enhanced_search': "Arama sürüyor — gelişmiş tanıma kullanılıyor…",
    'location_pin_permission': "Akustik Hafıza pinlerini göstermek için konum erişimine izin verin.",
    'match_found': 'Eşleşme Bulundu!',
    'mic_denied': 'Mikrofon izni reddedildi.',
    'settings_title': 'Uygulama Tercihleri',
    'pref_music_app': 'Tercih Edilen Müzik Uygulaması',    'pref_lang': 'Tercih Edilen Dil',
    'open_spotify': 'Spotify\'da Aç',
    'open_apple': 'Apple Music\'te Aç',
    'history_title': 'Arama Geçmişi',
    'clear_history': 'Geçmişi Temizle',
    'clear_history_confirm': 'Tüm arama geçmişini silmek istediğinize emin misiniz?',
    'no_history': 'Henüz şarkı aranmadı!',
    'cancel': 'İptal',
    'save': 'Kaydet',
    'clear': 'Temizle',
    'by': 'sanatçı',
    'User Manual': 'Nasıl Kullanılır',
    'getting_started': 'Başlarken',
    'step 1': 'Tercihlerini Ayarla',
    'step1_desc': 'Spotify veya Apple Music’i, tercih ettiğin dili, Auto Play’i açık veya kapalı olarak ve uygulama temasını seç.',
    'step 2': 'Ortamını Seç',
    'step2_desc': 'Sessiz, Gürültülü veya Dış Mekân seçeneklerinden birini seçerek Reczt’in bulunduğun ortama göre tanımayı optimize etmesine yardımcı ol.',
    'step 3': 'Şarkı Söyle, Mırıldan veya Bir Şarkı Çal',
    'step3_desc': 'Tanımayı başlatmak için mikrofona dokun veya Siri’yi kullan.',
    'step 4': 'Reczt En İyi Eşleşmeyi Bulsun',
    'step4_desc': 'Reczt şarkını belirlemek için birden fazla tanıma yöntemi kullanabilir. Sonuç belirsizse en olası eşleşmeler arasından seçim yapmanı isteyebilir.',
    'step 5': 'Sonucu Çal',
    'step5_desc': 'Auto Play açıkken Reczt eşleşmeyi tercih ettiğin müzik uygulamasında otomatik olarak açar. Tam parça doğrudan açılamazsa şarkı ve sanatçı için bir arama açabilir.',
    'step 6': 'Reczt’i Çevrimdışı Kullan',
    'step6_desc': 'İnternet bağlantını kaybedersen Reczt kaydını saklayabilir ve bağlantı geri geldiğinde işleyebilir.',
    'explore_more': 'Daha Fazlasını Keşfet',
    'step 7': 'Reczt Geçmişini Keşfet',
    'step7_desc': 'Hangi şarkıları söylediğini unuttun mu? Önceki şarkıları ve ses kliplerini incele veya Geçmişini tercih ettiğin müzik uygulamasında bir çalma listesine dönüştür.',
    'step 8': 'Analytics Verilerine Göz At',
    'step8_desc': 'Ana Ekrandan Analytics sayfasını açarak önerilen çalma listeni, en çok söylediğin türleri, en çok söylediğin sanatçıyı, günlük serini, duygu pasta grafiğini ve Acoustic Memory haritasını keşfet.',
    'step 9': 'QuickShare ile Paylaş',
    'step9_desc': 'Analytics ve Geçmiş sayfalarındaki QuickShare’i kullanarak tek tek şarkıları veya tüm Analytics sayfanı favori platformlarında paylaş.',
    'got it': 'Anladım!',
    'Outdoors': 'Dışarıda',
    'no_valid_match': 'Geçerli bir eşleşme dinamik güven puanına ulaşamadı. Tekrar deneyin!',
    'theme_title': 'Uygulama Renk Teması',
    'theme_purple': 'Derin Mor',
    'theme_blue': 'Okyanus Mavisi',
    'theme_emerald': 'Zümrüt',
    'theme_orange': 'Gün Batımı Turuncusu',
    'auto_play_title': 'Otomatik Oynat',
    'share_text': 'Reczt ile eller serbest olarak bulunan "{title}" by {artist}\'i kontrol edin!',
    'pending_queue_title': 'Bekleyen Çevrimdışı Aramalar',
    'offline_saved': 'İnternet yok. Çevrimdışı kuyruğa kaydedildi!',
'analytics_title': 'Reczt Analitik',
      'streak_title': 'Şarkı Söyleme Serisi',
      'days_active_suffix': 'Aktif Gün',
      'top_artist': 'En İyi Sanatçılar',
      'most_sung_genres': 'En Çok Seslendirilen Müzik Türleri',
      'acoustic_map': 'Akustik Bellek Haritası',
      'acoustic_map_desc': '🗺️ Tanınan şarkı konumu için iğneler yerleştirildi',
      'vibe_match_playlist': 'İki Haftalık Ruh Hali \n Uyumu Çalma Listesi',
      'playlist_countdown': '4 gün içinde otomatik güncelleme',
      'no_artist_data': 'En iyi sanatçıları takip etmek için daha fazla şarkı söyleyin!',
      'analyzing': 'Mod Analiz Ediliyor...',
      'next_drop': 'Sonraki Güncelleme',
      'refreshing_soon': 'Çok yakında yenileniyor!',
      'open_in': 'Şurada aç',
      'none': 'Hiçbiri',
      'sad': 'Üzgün',
    'happy': 'Mutlu',
    'hype': 'Heyecanlı',
    'romantic': 'Romantik',
    'rock': 'Rock',
    'jazz': 'Caz',
    'indie': 'Indie',
    'rap': 'Rap',
    'classical': 'Klasik',
    'reggae': 'Reggae',
    'r&b': 'R&B',
    'pop': 'Pop',
    'error_no_lyrics': 'Şarkı sözleri algılanamadı. Daha net söylemeyi deneyin!',
    'open_in_platform': "{platform}'da aç",
    'songs': 'şarkı',
    'playlist_desc': 'Reczt uygulaması aracılığıyla otomatik oluşturuldu',
    'auth_spotify': 'Spotify ile kimlik doğrulaması yapılıyor...',
    'auth_failed': 'Spotify yetkilendirmesi iptal edildi veya başarısız oldu.',
    'creating_playlist': 'Çalma listesi oluşturuluyor ve şarkılar aranıyor...',
    'playlist_success': 'Başarılı! Çalma listesi Spotify\'da oluşturuldu.',
    'playlist_error': 'Çalma listesi oluşturulamadı. Spotify\'ın bağlı olduğundan emin olun.',
    'tap_to_play_preferred': 'Tercih edilen uygulamada çalmak için dokunun',
    'play_singing_sample': 'Ses örneğini çal',
    'share_card': 'Paylaşım Kartı',
    'create_spotify_playlist': 'Spotify Çalma Listesi Oluştur',
    'create_apple_playlist': 'Apple Music Çalma Listesi Oluştur',
    'select_song_for_playlist': 'Önce en az bir şarkı seçin.',
    'apple_music_connecting': 'Apple Music’e bağlanılıyor...',
    'apple_playlist_creating': 'Apple Music çalma listesi oluşturuluyor...',
    'apple_playlist_success': 'Başarılı! Apple Music’te çalma listesi oluşturuldu.',
    'apple_playlist_partial': 'Apple Music’te çalma listesi oluşturuldu: {added} eklendi, {failed} bulunamadı.',
    'apple_playlist_error': 'Apple Music çalma listesi oluşturulamadı. Apple Music erişimini kontrol edip tekrar deneyin.',
    'analytics_share_text': 'Reczt\'teki müzik istatistiklerime göz at!',
    'calculating': 'Hesaplanıyor...',
    'connection_failed': 'Bağlantı başarısız oldu',
    'error_empty_path': 'Hata: Kayıt yolu boştu.',
    'error_stopping': 'Kaydı durdururken hata oluştu',
    'live_pin_label': 'CANLI',
    'playlist_name': 'Reczt Müzik Geçmişi',
    'quickshare_tooltip': 'Hızlı Paylaş',
    'server_error': 'Sunucu hatası',
    'unknown_artist': 'Bilinmeyen Sanatçı',
    'opening_apple_search': 'Şunun için Apple Music araması açılıyor:',
    'processing_saved_recording': 'Kaydedilen kayıt işleniyor...',
    'queued_song_found': 'Reczt, kuyruktaki şarkınızı buldu!',
    'found_offline_badge': "Çevrimdışıyken bulundu",
    'found_offline_detail': "Çevrimdışı kuyruğunuzdan tanındı",
  
    'waiting_for_voice': 'Sesiniz bekleniyor...',
    'signal_good': 'İyi sinyal',
    'sing_louder': 'Biraz daha yüksek sesle söyleyin',
    'top_guesses_title': 'En iyi tahminler',
    'top_guesses_subtitle': 'Tam olarak emin değilim. Aradığınız şarkıya dokunun.',
    'confidence': 'eşleşme',
    'retry_search': 'Son kaydı yeniden ara',
    'search_timed_out': 'Arama çok uzun sürdü. Lütfen tekrar deneyin.',
    'stop_recording': 'Kaydı durdur',
    'other': 'Diğer',
  },
  'ar': {
    "clear_this_data": 'مسح هذه البيانات؟',
    "clear_this_data_confirm": 'هل تريد مسح بيانات {section} فقط؟ ستبقى بيانات Reczt الأخرى كما هي.',
    "data_box_cleared": 'تم مسح بيانات هذه البطاقة.',
    "emotions": 'المشاعر',
    "cleared": 'تم المسح',
    'clear_reczt_data': 'مسح بيانات Reczt',
    'clear_reczt_data_desc': 'يحذف من هذا الجهاز السجل ومقاطع الغناء والتحليلات ودبابيس Acoustic Memory والتسجيلات غير المتصلة المنتظرة. يتم الاحتفاظ بتفضيلات التطبيق.',
    'clear_reczt_data_confirm': 'سيؤدي هذا إلى حذف سجل الأغاني ومقاطع الغناء والتحليلات ومواقع Acoustic Memory والتسجيلات غير المتصلة المنتظرة نهائيًا من هذا الجهاز. سيتم الاحتفاظ باللغة وتطبيق الموسيقى والمظهر وAuto Play والتفضيلات القانونية. لا يمكن التراجع عن هذا الإجراء.',
    'clear_data_action': 'مسح البيانات',
    'clear_reczt_data_success': 'تم مسح بيانات Reczt من هذا الجهاز.',
    'clear_reczt_data_error': 'تعذر على Reczt مسح جميع البيانات المحلية. حاول مرة أخرى.',
    'legal_privacy': 'القانون والخصوصية',
    'privacy_policy': 'سياسة الخصوصية',
    'terms_of_use': 'شروط الاستخدام',
    'open_source_licenses': 'تراخيص المصادر المفتوحة',
    'legal_notice_title': 'مرحبًا بك في Reczt',
    'legal_notice_body': 'قبل استخدام Reczt، يرجى مراجعة سياسة الخصوصية وشروط الاستخدام. بالضغط على موافق ومتابعة، فإنك توافق على الشروط وتقر بسياسة الخصوصية.',
    'legal_accept': 'موافق ومتابعة',
    'legal_close': 'إغلاق',
    'view_online': 'عرض عبر الإنترنت',
    'app_title': 'محدد الأغاني',
    'where_are_you': 'أين أنت؟',
    'quiet_room': 'غرفة هادئة',
    'loud_room': 'مكان صاخب',
    'initial_status': 'ابك واضغط على الميكروفوناختر البيئة الخاصة أو قُل: "Hey Siri, Activate Reczt!',
    'listening': 'جاري الاستماع...',
    'searching': 'جاري البحث...',
    'enhanced_search': "ما زال البحث جارياً — يتم استخدام التعرّف المتقدم…",
    'location_pin_permission': "اسمح بالوصول إلى الموقع لإظهار دبابيس الذاكرة الصوتية.",
    'match_found': 'تم العثور على الأغنية!',
    'mic_denied': 'تم رفض إذن الميكروفون.',
    'settings_title': 'تفضيلات التطبيق',
    'pref_music_app': 'تطبيق الموسيقى المفضل',    'pref_lang': 'اللغة المفضلة',
    'open_spotify': 'فتح في Spotify',
    'open_apple': 'فتح في Apple Music',
    'history_title': 'سجل البحث',
    'clear_history': 'مسح السجل',
    'clear_history_confirm': 'هل أنت تأكد من رغبتك في حذف جميع عمليات البحث؟',
    'no_history': 'لم يتم البحث عن أغاني بعد!',
    'cancel': 'إلغاء',
    'save': 'حفظ',
    'clear': 'مسح',
    'by': 'بواسطة',
    'User Manual': 'كيفية الاستخدام',
    'getting_started': 'البدء',
    'step 1': 'اضبط تفضيلاتك',
    'step1_desc': 'اختر Spotify أو Apple Music، ولغتك المفضلة، وشغّل Auto Play أو أوقفه، واختر مظهر التطبيق.',
    'step 2': 'اختر بيئتك',
    'step2_desc': 'اختر هادئ أو صاخب أو في الخارج لمساعدة Reczt على تحسين التعرّف وفقًا للبيئة المحيطة بك.',
    'step 3': 'غنِّ أو همهم أو شغّل أغنية',
    'step3_desc': 'اضغط على الميكروفون أو استخدم Siri لبدء التعرّف.',
    'step 4': 'دع Reczt يجد أفضل تطابق',
    'step4_desc': 'قد يستخدم Reczt عدة طرق للتعرّف لتحديد أغنيتك. إذا كانت النتيجة غير واضحة، فقد يطلب منك Reczt الاختيار بين أكثر التطابقات احتمالًا.',
    'step 5': 'شغّل النتيجة',
    'step5_desc': 'عند تشغيل Auto Play، يفتح Reczt التطابق تلقائيًا في تطبيق الموسيقى المفضل لديك. إذا تعذّر فتح المقطع الدقيق مباشرةً، فقد يفتح بحثًا عن الأغنية والفنان بدلًا من ذلك.',
    'step 6': 'استخدم Reczt دون اتصال',
    'step6_desc': 'إذا انقطع اتصالك بالإنترنت، يمكن لـ Reczt حفظ تسجيلك ومعالجته عند عودة الاتصال.',
    'explore_more': 'اكتشف المزيد',
    'step 7': 'استكشف سجل Reczt',
    'step7_desc': 'نسيت الأغاني التي غنيتها؟ راجع الأغاني السابقة ومقاطع الصوت، أو حوّل السجل إلى قائمة تشغيل في تطبيق الموسيقى المفضل لديك.',
    'step 8': 'اطّلع على Analytics',
    'step8_desc': 'انتقل إلى صفحة Analytics من الشاشة الرئيسية لاستكشاف قائمة التشغيل المقترحة، والأنواع الأكثر غناءً، وأفضل فنان، وسلسلة الأيام، والمخطط الدائري للمشاعر، وخريطة Acoustic Memory.',
    'step 9': 'شارك باستخدام QuickShare',
    'step9_desc': 'استخدم QuickShare من صفحتي Analytics والسجل لمشاركة أغنيات فردية أو صفحة Analytics كاملة عبر منصاتك المفضلة.',
    'got it': 'فهمت!',
    'Outdoors': 'في الهواء الطلق',
    'no_valid_match': 'لم يصل أي تطابق صالح إلى درجة الثقة الديناميكية. حاول مرة أخرى!',
    'theme_title': 'موضوع لون التطبيق',
    'theme_purple': 'أرجواني غامق',
    'theme_blue': 'أزرق المحيط',
    'theme_emerald': 'زمردي نيون',
    'theme_orange': 'برتقالي الغروب',
    'auto_play_title': 'تشغيل تلقائي',
    'share_text': 'تحقق من "{title}" بواسطة {artist}, تم العثور عليه بدون استخدام اليدين باستخدام Reczt!',
    'pending_queue_title': 'عمليات البحث غير المتصلة بالإنترنت المعلقة',
    'offline_saved': 'لا يوجد اتصال بالإنترنت. تم الحفظ في قائمة الانتظار غير المتصلة بالإنترنت!',
'analytics_title': 'تحليلات Reczt',
      'streak_title': 'سلسلة الغناء المتواصلة',
      'days_active_suffix': 'أيام نشطة',
      'top_artist': 'أبرز الفنانين',
      'most_sung_genres': 'أنواع الأغاني الأكثر أداءً',
      'acoustic_map': 'خريطة الذاكرة الصوتية',
      'acoustic_map_desc': '🗺️ تم وضع دبابيس لمواقع الأغاني التعرف عليها',
      'vibe_match_playlist': 'قائمة تشغيل توافق المزاج',
      'playlist_countdown': 'التحديث التلقائي القادم خلال 4 أيام',
      'no_artist_data': 'غنّ المزيد من الأغاني لتتبع أفضل الفنانين!',
      'analyzing': 'جاري تحليل الحالة المزاجية...',
      'next_drop': 'التحديث القادم',
      'refreshing_soon': 'سيتم التحديث قريباً!',
      'open_in': 'فتح في',
      'none': 'لا أحد',
      'sad': 'حزين',
    'happy': 'سعيد',
    'hype': 'حماسي',
    'romantic': 'رومانسي',
    'rock': 'روك',
    'jazz': 'جاز',
    'indie': 'إيندي',
    'rap': 'راب',
    'classical': 'كلاسيكي',
    'reggae': 'ريغي',
    'r&b': 'آر أند بي',
    'pop': 'بوب',
    'error_no_lyrics': 'تعذر التعرف على الكلمات. حاول الغناء بشكل أوضح!',
    'open_in_platform': 'الفتح في {platform}',
    'songs': 'أغاني',
    'playlist_desc': 'تم إنشاؤه تلقائيًا عبر تطبيق Reczt',
    'auth_spotify': 'جاري المصادقة مع Spotify...',
    'auth_failed': 'تم إلغاء تفويض Spotify أو فشله.',
    'creating_playlist': 'جاري إنشاء قائمة التشغيل والبحث عن الأغاني...',
    'playlist_success': 'نجاح! تم إنشاء قائمة التشغيل في Spotify.',
    'playlist_error': 'تعذر إنشاء قائمة التشغيل. تأكد من اتصال Spotify.',
    'tap_to_play_preferred': 'انقر للتشغيل في تطبيقك المفضل',
    'play_singing_sample': 'تشغيل عينة الغناء',
    'share_card': 'بطاقة المشاركة',
    'create_spotify_playlist': 'إنشاء قائمة تشغيل Spotify',
    'create_apple_playlist': 'إنشاء قائمة تشغيل Apple Music',
    'select_song_for_playlist': 'اختر أغنية واحدة على الأقل أولاً.',
    'apple_music_connecting': 'جارٍ الاتصال بـ Apple Music...',
    'apple_playlist_creating': 'جارٍ إنشاء قائمة تشغيل Apple Music...',
    'apple_playlist_success': 'تم بنجاح! تم إنشاء قائمة التشغيل في Apple Music.',
    'apple_playlist_partial': 'تم إنشاء قائمة التشغيل في Apple Music: تمت إضافة {added}، وتعذر العثور على {failed}.',
    'apple_playlist_error': 'تعذر إنشاء قائمة تشغيل Apple Music. تحقق من صلاحية الوصول إلى Apple Music وحاول مرة أخرى.',
    'analytics_share_text': 'شاهد إحصائيات موسيقاي على Reczt!',
    'calculating': 'جارٍ الحساب...',
    'connection_failed': 'فشل الاتصال',
    'error_empty_path': 'خطأ: مسار التسجيل كان فارغًا.',
    'error_stopping': 'خطأ أثناء إيقاف التسجيل',
    'live_pin_label': 'مباشر',
    'playlist_name': 'سجل موسيقى Reczt',
    'quickshare_tooltip': 'مشاركة سريعة',
    'server_error': 'خطأ في الخادم',
    'unknown_artist': 'فنان غير معروف',
    'opening_apple_search': 'جارٍ فتح بحث Apple Music عن',
    'processing_saved_recording': 'جارٍ معالجة التسجيل المحفوظ...',
    'queued_song_found': 'لقد عثر Reczt على أغنيتك المنتظرة في قائمة الانتظار!',
    'found_offline_badge': "تم العثور عليها دون اتصال",
    'found_offline_detail': "تم التعرّف عليها من قائمة الانتظار دون اتصال",
  
    'waiting_for_voice': 'بانتظار صوتك...',
    'signal_good': 'الإشارة جيدة',
    'sing_louder': 'غنِّ بصوت أعلى قليلًا',
    'top_guesses_title': 'أفضل الاحتمالات',
    'top_guesses_subtitle': 'لست متأكدًا تمامًا. اضغط على الأغنية التي تقصدها.',
    'confidence': 'تطابق',
    'retry_search': 'إعادة محاولة آخر تسجيل',
    'search_timed_out': 'استغرق البحث وقتًا طويلًا. حاول مرة أخرى.',
    'stop_recording': 'إيقاف التسجيل',
    'other': 'أخرى',
  },
  'nl': {
    "clear_this_data": 'Deze gegevens wissen?',
    "clear_this_data_confirm": 'Alleen de gegevens van {section} wissen? Je andere Reczt-gegevens blijven behouden.',
    "data_box_cleared": 'De gegevens van deze kaart zijn gewist.',
    "emotions": 'Emoties',
    "cleared": 'Gewist',
    'clear_reczt_data': 'Reczt-gegevens wissen',
    'clear_reczt_data_desc': 'Verwijdert van dit apparaat geschiedenis, zangclips, analyses, Acoustic Memory-pinnen en offline opnamen in de wachtrij. Appvoorkeuren blijven behouden.',
    'clear_reczt_data_confirm': 'Hiermee worden je opgeslagen songgeschiedenis, zangclips, analyses, Acoustic Memory-locaties en offline opnamen in de wachtrij permanent van dit apparaat verwijderd. Taal, muziekapp, thema, Auto Play en juridische voorkeuren blijven behouden. Dit kan niet ongedaan worden gemaakt.',
    'clear_data_action': 'Gegevens wissen',
    'clear_reczt_data_success': 'De Reczt-gegevens zijn van dit apparaat gewist.',
    'clear_reczt_data_error': 'Reczt kon niet alle lokale gegevens wissen. Probeer het opnieuw.',
    'legal_privacy': 'Juridisch & privacy',
    'privacy_policy': 'Privacybeleid',
    'terms_of_use': 'Gebruiksvoorwaarden',
    'open_source_licenses': 'Open-sourcelicenties',
    'legal_notice_title': 'Welkom bij Reczt',
    'legal_notice_body': 'Lees voordat je Reczt gebruikt het Privacybeleid en de Gebruiksvoorwaarden. Door op Akkoord en doorgaan te tikken, ga je akkoord met de voorwaarden en erken je het Privacybeleid.',
    'legal_accept': 'Akkoord en doorgaan',
    'legal_close': 'Sluiten',
    'view_online': 'Online bekijken',
    'app_title': 'Nummer Herkenner',
    'where_are_you': 'Waar ben je?',
    'quiet_room': 'Een stille ruimte',
    'loud_room': 'Een drukke ruimte',
    'initial_status': 'Selecteer je omgeving en tik op de microfoon of zeg: "Hey Siri, activeer Reczt"!',
    'listening': 'Luisteren...',
    'searching': 'Database zoeken...',
    'enhanced_search': "Nog aan het zoeken — geavanceerde herkenning wordt gebruikt…",
    'location_pin_permission': "Sta locatietoegang toe om Acoustic Memory-pinnen te plaatsen.",
    'match_found': 'Nummer Gevonden!',
    'mic_denied': 'Microfoontoegang geweigerd.',
    'settings_title': 'App Voorkeuren',
    'pref_music_app': 'Voorkeursmuziek-app',    'pref_lang': 'Voorkeurstaal',
    'open_spotify': 'Openen in Spotify',
    'open_apple': 'Openen in Apple Music',
    'history_title': 'Zoekgeschiedenis',
    'clear_history': 'Geschiedenis Wissselen',
    'clear_history_confirm': 'Weet je zeker dat je alle zoekopdrachten wilt wissselen?',
    'no_history': 'Nog geen nummers gezocht!',
    'cancel': 'Annuleren',
    'save': 'Opslaan',
    'clear': 'Wissselen',
    'by': 'door',
    'User Manual': 'Hoe te gebruiken',
    'getting_started': 'Aan de slag',
    'step 1': 'Stel je voorkeuren in',
    'step1_desc': 'Kies Spotify of Apple Music, je voorkeurstaal, zet Auto Play aan of uit en kies je app-thema.',
    'step 2': 'Kies je omgeving',
    'step2_desc': 'Kies Stil, Luid of Buiten om Reczt te helpen de herkenning af te stemmen op je omgeving.',
    'step 3': 'Zing, neurie of speel een nummer af',
    'step3_desc': 'Tik op de microfoon of gebruik Siri om de herkenning te starten.',
    'step 4': 'Laat Reczt de beste match vinden',
    'step4_desc': 'Reczt kan meerdere herkenningsmethoden gebruiken om je nummer te identificeren. Als het resultaat dubbelzinnig is, kan Reczt je vragen te kiezen uit de meest waarschijnlijke matches.',
    'step 5': 'Speel het resultaat af',
    'step5_desc': 'Met Auto Play aan opent Reczt de match automatisch in je favoriete muziekapp. Als het exacte nummer niet rechtstreeks kan worden geopend, kan Reczt in plaats daarvan een zoekopdracht naar nummer en artiest openen.',
    'step 6': 'Gebruik Reczt offline',
    'step6_desc': 'Als je internetverbinding wegvalt, kan Reczt je opname bewaren en verwerken zodra de verbinding terug is.',
    'explore_more': 'Ontdek meer',
    'step 7': 'Ontdek je Reczt-geschiedenis',
    'step7_desc': 'Vergeten welke nummers je hebt gezongen? Bekijk eerdere nummers en audioclips of maak van je Geschiedenis een afspeellijst in je favoriete muziekapp.',
    'step 8': 'Bekijk je Analytics',
    'step8_desc': 'Ga vanaf het beginscherm naar de Analytics-pagina om je aanbevolen afspeellijst, meest gezongen genres, topartiest, dagelijkse reeks, emotiecirkeldiagram en Acoustic Memory-kaart te bekijken.',
    'step 9': 'Deel met QuickShare',
    'step9_desc': 'Gebruik QuickShare op de pagina’s Analytics en Geschiedenis om losse nummers of je volledige Analytics-pagina te delen via je favoriete platforms.',
    'got it': 'Verstanden!',
    'Outdoors': 'Op het plaatje',
    'no_valid_match': 'Geen geldige match voldoet aan de dynamische vertrouwensscore. Probeer het opnieuw!',
    'theme_title': 'App Kleur Théma',
    'theme_purple': 'Diep Paars',
    'theme_blue': 'Oceaan Blauw',
    'theme_emerald': 'Smaragd',
    'theme_orange': 'Zonsondergang Oranje',
    'auto_play_title': 'Automatisch afspelen',
    'share_text': 'Bekijk "{title}" van {artist}, gevonden zonder handen met Reczt!',
    'pending_queue_title': 'In afwachting van offline zoekopdrachten',
    'offline_saved': 'Geen internet. Opgeslagen in de offline wachtrij!',
'analytics_title': 'Reczt-analyse',
      'streak_title': 'Zangreeks',
      'days_active_suffix': 'Actieve dagen',
      'top_artist': 'Topartiesten',
      'most_sung_genres': 'Meest gezongen genres',
      'acoustic_map': 'Akoestische geheugenkaart',
      'acoustic_map_desc': '🗺️ Pinnen geplaatst voor herkende nummerlocaties',
      'vibe_match_playlist': 'Tweewekelijkse \n Vibe Match-playlist',
      'playlist_countdown': 'Volgende auto-update over 4 dagen',
      'no_artist_data': 'Zing meer nummers om topartiesten te volgen!',
      'analyzing': 'Stemming analyseren...',
      'next_drop': 'Volgende drop',
      'refreshing_soon': 'Binnenkort vernieuwd!',
      'open_in': 'Openen in',
      'none': 'Geen',
      'sad': 'Verdrietig',
    'happy': 'Blij',
    'hype': 'Enthousiast',
    'romantic': 'Romantisch',
    'rock': 'Rock',
    'jazz': 'Jazz',
    'indie': 'Indie',
    'rap': 'Rap',
    'classical': 'Klassiek',
    'reggae': 'Reggae',
    'r&b': 'R&B',
    'pop': 'Pop',
    'error_no_lyrics': 'Kon de songtekst niet herkennen. Probeer duidelijker te zingen!',
    'open_in_platform': 'Openen in {platform}',
    'songs': 'nummers',
    'playlist_desc': 'Automatisch gemaakt via de Reczt-app',
    'auth_spotify': 'Authenticeren met Spotify...',
    'auth_failed': 'Spotify-autorisatie geannuleerd of mislukt.',
    'creating_playlist': 'Afspeellijst maken en nummers zoeken...',
    'playlist_success': 'Succes! Afspeellijst gemaakt in Spotify.',
    'playlist_error': 'Kan afspeellijst niet maken. Zorg ervoor dat Spotify is verbonden.',
    'tap_to_play_preferred': 'Tik om af te spelen in je voorkeursapp',
    'play_singing_sample': 'Zangvoorbeeld afspelen',
    'share_card': 'Deelkaart',
    'create_spotify_playlist': 'Spotify-afspeellijst maken',
    'create_apple_playlist': 'Apple Music-afspeellijst maken',
    'select_song_for_playlist': 'Selecteer eerst minstens één nummer.',
    'apple_music_connecting': 'Verbinding maken met Apple Music...',
    'apple_playlist_creating': 'Apple Music-afspeellijst maken...',
    'apple_playlist_success': 'Gelukt! Afspeellijst aangemaakt in Apple Music.',
    'apple_playlist_partial': 'Afspeellijst aangemaakt in Apple Music: {added} toegevoegd, {failed} niet gevonden.',
    'apple_playlist_error': 'De Apple Music-afspeellijst kon niet worden gemaakt. Controleer de toegang tot Apple Music en probeer het opnieuw.',
    'analytics_share_text': 'Bekijk mijn muziekstatistieken op Reczt!',
    'calculating': 'Berekenen...',
    'connection_failed': 'Verbinding mislukt',
    'error_empty_path': 'Fout: het opnamepad was leeg.',
    'error_stopping': 'Fout bij het stoppen van de opname',
    'live_pin_label': 'LIVE',
    'playlist_name': 'Reczt Muziekgeschiedenis',
    'quickshare_tooltip': 'Snel delen',
    'server_error': 'Serverfout',
    'unknown_artist': 'Onbekende artiest',
    'opening_apple_search': 'Apple Music-zoekopdracht wordt geopend voor',
    'processing_saved_recording': 'Opgeslagen opname wordt verwerkt...',
    'queued_song_found': 'Reczt heeft je wachtende nummer gevonden!',
    'found_offline_badge': "Offline gevonden",
    'found_offline_detail': "Herkend vanuit je offlinewachtrij",
  
    'waiting_for_voice': 'Wachten op je stem...',
    'signal_good': 'Goed signaal',
    'sing_louder': 'Zing iets harder',
    'top_guesses_title': 'Beste gokjes',
    'top_guesses_subtitle': 'Ik weet het niet helemaal zeker. Tik op het nummer dat je bedoelde.',
    'confidence': 'match',
    'retry_search': 'Laatste opname opnieuw zoeken',
    'search_timed_out': 'Het zoeken duurde te lang. Probeer het opnieuw.',
    'stop_recording': 'Opname stoppen',
    'other': 'Overig',
  },
  'pl': {
    "clear_this_data": 'Wyczyścić te dane?',
    "clear_this_data_confirm": 'Wyczyścić tylko dane {section}? Pozostałe dane Reczt zostaną zachowane.',
    "data_box_cleared": 'Dane tej karty zostały wyczyszczone.',
    "emotions": 'Emocje',
    "cleared": 'Wyczyszczono',
    'clear_reczt_data': 'Wyczyść dane Reczt',
    'clear_reczt_data_desc': 'Usuwa z tego urządzenia historię, nagrania śpiewu, analizy, pinezki Acoustic Memory i oczekujące nagrania offline. Ustawienia aplikacji pozostają zachowane.',
    'clear_reczt_data_confirm': 'Spowoduje to trwałe usunięcie z tego urządzenia historii utworów, nagrań śpiewu, analiz, lokalizacji Acoustic Memory i oczekujących nagrań offline. Język, aplikacja muzyczna, motyw, Auto Play i ustawienia prawne pozostaną zachowane. Tej operacji nie można cofnąć.',
    'clear_data_action': 'Wyczyść dane',
    'clear_reczt_data_success': 'Dane Reczt zostały usunięte z tego urządzenia.',
    'clear_reczt_data_error': 'Reczt nie mógł usunąć wszystkich danych lokalnych. Spróbuj ponownie.',
    'legal_privacy': 'Informacje prawne i prywatność',
    'privacy_policy': 'Polityka prywatności',
    'terms_of_use': 'Warunki użytkowania',
    'open_source_licenses': 'Licencje open source',
    'legal_notice_title': 'Witamy w Reczt',
    'legal_notice_body': 'Przed użyciem Reczt zapoznaj się z Polityką prywatności i Warunkami użytkowania. Klikając Akceptuję i kontynuuję, akceptujesz Warunki i potwierdzasz zapoznanie się z Polityką prywatności.',
    'legal_accept': 'Akceptuję i kontynuuję',
    'legal_close': 'Zamknij',
    'view_online': 'Wyświetl online',
    'app_title': 'Rozpoznawanie Muzyki',
    'where_are_you': 'Gdzie jesteś?',
    'quiet_room': 'Ciche pomieszczenie',
    'loud_room': 'Głośne otoczenie',
    'initial_status': 'Wybierz swoje środowisko i stuknij w mikrofon lub powiedz Hej Siri, Aktywuj Reczt!',
    'listening': 'Słucham...',
    'searching': 'Wyszukiwanie w bazie...',
    'enhanced_search': "Wciąż szukam — używam rozszerzonego rozpoznawania…",
    'location_pin_permission': "Zezwól na dostęp do lokalizacji, aby dodawać pinezki Acoustic Memory.",
    'match_found': 'Znaleziono utwór!',
    'mic_denied': 'Odmowa dostępu do mikrofonu.',
    'settings_title': 'Preferencje Aplikacji',
    'pref_music_app': 'Preferowana aplikacja muzyczna',    'pref_lang': 'Preferowany język',
    'open_spotify': 'Otwórz w Spotify',
    'open_apple': 'Otwórz w Apple Music',
    'history_title': 'Historia wyszukiwania',
    'clear_history': 'Wyczyść historię',
    'clear_history_confirm': 'Czy na pewno chcesz usunąć całą historię?',
    'no_history': 'Nie wyszukano jeszcze żadnych piosenek!',
    'cancel': 'Anuluj',
    'save': 'Zapisz',
    'clear': 'Wyczyść',
    'by': 'wykonawca',
    'User Manual': 'Jak korzystać',
    'getting_started': 'Pierwsze kroki',
    'step 1': 'Ustaw swoje preferencje',
    'step1_desc': 'Wybierz Spotify lub Apple Music, preferowany język, włącz lub wyłącz Auto Play i wybierz motyw aplikacji.',
    'step 2': 'Wybierz otoczenie',
    'step2_desc': 'Wybierz Cicho, Głośno lub Na zewnątrz, aby pomóc Reczt zoptymalizować rozpoznawanie do Twojego otoczenia.',
    'step 3': 'Śpiewaj, nuć lub odtwórz utwór',
    'step3_desc': 'Dotknij mikrofonu lub użyj Siri, aby rozpocząć rozpoznawanie.',
    'step 4': 'Pozwól Reczt znaleźć najlepsze dopasowanie',
    'step4_desc': 'Reczt może używać kilku metod rozpoznawania, aby zidentyfikować utwór. Jeśli wynik jest niejednoznaczny, Reczt może poprosić Cię o wybór spośród najbardziej prawdopodobnych dopasowań.',
    'step 5': 'Odtwórz wynik',
    'step5_desc': 'Gdy Auto Play jest włączone, Reczt automatycznie otwiera dopasowanie w preferowanej aplikacji muzycznej. Jeśli nie może bezpośrednio otworzyć dokładnego utworu, może zamiast tego otworzyć wyszukiwanie nazwy utworu i wykonawcy.',
    'step 6': 'Używaj Reczt offline',
    'step6_desc': 'Jeśli stracisz połączenie z internetem, Reczt może zapisać nagranie i przetworzyć je po przywróceniu połączenia.',
    'explore_more': 'Odkryj więcej',
    'step 7': 'Przeglądaj historię Reczt',
    'step7_desc': 'Nie pamiętasz, jakie utwory śpiewałeś? Przejrzyj poprzednie utwory i klipy audio albo zmień Historię w playlistę w preferowanej aplikacji muzycznej.',
    'step 8': 'Sprawdź swoje Analytics',
    'step8_desc': 'Otwórz stronę Analytics z ekranu głównego, aby zobaczyć polecaną playlistę, najczęściej śpiewane gatunki, topowego artystę, codzienną serię, wykres kołowy emocji i mapę Acoustic Memory.',
    'step 9': 'Udostępniaj przez QuickShare',
    'step9_desc': 'Używaj QuickShare na stronach Analytics i Historia, aby udostępniać pojedyncze utwory lub całą stronę Analytics na ulubionych platformach.',
    'got it': 'Zrozumiano!',
    'Outdoors': 'Na zewnątrz',
    'no_valid_match': 'Geen geldige match voldoet aan de dynamische vertrouwensscore. Probeer het opnieuw!',
    'theme_title': 'Temat koloru aplikacji',
    'theme_purple': 'Głęboki fiolet',
    'theme_blue': 'Oceaniczny niebieski',
    'theme_emerald': 'Smaragdowy',
    'theme_orange': 'Pomarańczowy zachód słońca',
    'auto_play_title': 'Automatyczne odtwarzanie',
    'share_text': 'Sprawdź "{title}" by {artist}, znaleziony bez użycia rąk za pomocą Reczt!',
    'pending_queue_title': 'Oczekujące wyszukiwania offline',
    'offline_saved': 'Brak internetu. Zapisano w kolejce offline!',
'analytics_title': 'Reczt Analytics',
      'streak_title': 'Seria dni śpiewania',
      'days_active_suffix': 'Aktywnych dni',
      'top_artist': 'Najpopularniejsi artyści',
      'most_sung_genres': 'Najczęściej wykonywane gatunki',
      'acoustic_map': 'Akustyczna mapa pamięci',
      'acoustic_map_desc': '🗺️ Przypięte znaczniki dla rozpoznanych lokalizacji piosenek',
      'vibe_match_playlist': 'Playlista Vibe Match – co dwa tygodnie',
      'playlist_countdown': 'Kolejna automatyczna aktualizacja za 4 dni',
      'no_artist_data': 'Zaśpiewaj więcej utworów, aby śledzić ulubionych artystów!',
      'analyzing': 'Analizowanie nastroju...',
      'next_drop': 'Kolejna aktualizacja',
      'refreshing_soon': 'Wkrótce odświeżenie!',
      'open_in': 'Otwórz w',
      'none': 'Nic',
      'sad': 'Smutny',
    'happy': 'Szczęśliwy',
    'hype': 'Podekscytowany',
    'romantic': 'Romantyczny',
    'rock': 'Rock',
    'jazz': 'Jazz',
    'indie': 'Indie',
    'rap': 'Rap',
    'classical': 'Klasyczna',
    'reggae': 'Reggae',
    'r&b': 'R&B',
    'pop': 'Pop',
    'error_no_lyrics': 'Nie udało się rozpoznać tekstu. Spróbuj śpiewać wyraźniej!',
    'open_in_platform': 'Otwórz w {platform}',
    'songs': 'piosenek',
    'playlist_desc': 'Utworzono automatycznie za pomocą aplikacji Reczt',
    'auth_spotify': 'Uwierzytelnianie w Spotify...',
    'auth_failed': 'Autoryzacja Spotify została anulowana lub nie powiodła się.',
    'creating_playlist': 'Tworzenie playlisty i wyszukiwanie utworów...',
    'playlist_success': 'Sukces! Utworzono playlistę w Spotify.',
    'playlist_error': 'Nie można utworzyć playlisty. Upewnij się, że Spotify jest połączone.',
    'tap_to_play_preferred': 'Dotknij, aby odtworzyć w preferowanej aplikacji',
    'play_singing_sample': 'Odtwórz próbkę śpiewu',
    'share_card': 'Karta udostępniania',
    'create_spotify_playlist': 'Utwórz playlistę Spotify',
    'create_apple_playlist': 'Utwórz playlistę Apple Music',
    'select_song_for_playlist': 'Najpierw wybierz co najmniej jeden utwór.',
    'apple_music_connecting': 'Łączenie z Apple Music...',
    'apple_playlist_creating': 'Tworzenie playlisty Apple Music...',
    'apple_playlist_success': 'Gotowe! Playlista została utworzona w Apple Music.',
    'apple_playlist_partial': 'Playlista utworzona w Apple Music: dodano {added}, nie znaleziono {failed}.',
    'apple_playlist_error': 'Nie udało się utworzyć playlisty Apple Music. Sprawdź dostęp do Apple Music i spróbuj ponownie.',
    'analytics_share_text': 'Sprawdź moje statystyki muzyczne w Reczt!',
    'calculating': 'Obliczanie...',
    'connection_failed': 'Nie udało się połączyć',
    'error_empty_path': 'Błąd: ścieżka nagrania była pusta.',
    'error_stopping': 'Błąd podczas zatrzymywania nagrywania',
    'live_pin_label': 'NA ŻYWO',
    'playlist_name': 'Historia muzyki Reczt',
    'quickshare_tooltip': 'Szybkie udostępnianie',
    'server_error': 'Błąd serwera',
    'unknown_artist': 'Nieznany wykonawca',
    'opening_apple_search': 'Otwieranie wyszukiwania Apple Music dla',
    'processing_saved_recording': 'Przetwarzanie zapisanego nagrania...',
    'queued_song_found': 'Reczt znalazł Twoją oczekującą piosenkę!',
    'found_offline_badge': "Znaleziono offline",
    'found_offline_detail': "Rozpoznano z kolejki offline",
  
    'waiting_for_voice': 'Czekam na Twój głos...',
    'signal_good': 'Dobry sygnał',
    'sing_louder': 'Zaśpiewaj trochę głośniej',
    'top_guesses_title': 'Najlepsze typy',
    'top_guesses_subtitle': 'Nie mam całkowitej pewności. Dotknij właściwej piosenki.',
    'confidence': 'dopasowanie',
    'retry_search': 'Ponów ostatnie nagranie',
    'search_timed_out': 'Wyszukiwanie trwało zbyt długo. Spróbuj ponownie.',
    'stop_recording': 'Zatrzymaj nagrywanie',
    'other': 'Inne',
  },
};


/// Localized strings used only by the hands-free two-song voice chooser.
/// Kept separate from the main UI table so this feature can evolve without
/// disturbing the rest of Reczt's translations.
const Map<String, Map<String, String>> _voiceChoiceStrings = {
  'en': {
    'prompt': 'Reczt found two good matches. First: {song1}, by {artist1}. Second: {song2}, by {artist2}. Which one was right? Say first or second.',
    'listening': 'Listening for your choice...',
    'failed': 'I didn\'t catch that. Tap the correct song below.',
  },
  'es': {
    'prompt': 'Reczt encontró dos buenas coincidencias. Primera: {song1}, de {artist1}. Segunda: {song2}, de {artist2}. ¿Cuál era la correcta? Di primera o segunda.',
    'listening': 'Escuchando tu elección...',
    'failed': 'No entendí tu respuesta. Toca la canción correcta abajo.',
  },
  'fr': {
    'prompt': 'Reczt a trouvé deux bons résultats. Premier : {song1}, de {artist1}. Deuxième : {song2}, de {artist2}. Lequel était le bon ? Dites premier ou deuxième.',
    'listening': 'J’écoute votre choix...',
    'failed': 'Je n’ai pas compris. Touchez la bonne chanson ci-dessous.',
  },
  'de': {
    'prompt': 'Reczt hat zwei gute Treffer gefunden. Erstens: {song1}, von {artist1}. Zweitens: {song2}, von {artist2}. Welcher war richtig? Sag erste oder zweite.',
    'listening': 'Ich höre auf deine Auswahl...',
    'failed': 'Das habe ich nicht verstanden. Tippe unten auf den richtigen Song.',
  },
  'it': {
    'prompt': 'Reczt ha trovato due buone corrispondenze. Prima: {song1}, di {artist1}. Seconda: {song2}, di {artist2}. Qual era quella giusta? Di\' prima o seconda.',
    'listening': 'Sto ascoltando la tua scelta...',
    'failed': 'Non ho capito. Tocca il brano corretto qui sotto.',
  },
  'pt': {
    'prompt': 'O Reczt encontrou duas boas opções. Primeira: {song1}, de {artist1}. Segunda: {song2}, de {artist2}. Qual era a correta? Diga primeira ou segunda.',
    'listening': 'Ouvindo sua escolha...',
    'failed': 'Não entendi. Toque na música correta abaixo.',
  },
  'ja': {
    'prompt': 'Recztは2つの有力な候補を見つけました。1つ目。{artist1}の{song1}。2つ目。{artist2}の{song2}。正しいのはどちらですか？「1番目」または「2番目」と言ってください。',
    'listening': '選択を聞いています…',
    'failed': '聞き取れませんでした。下の正しい曲をタップしてください。',
  },
  'ko': {
    'prompt': 'Reczt가 두 개의 유력한 후보를 찾았습니다. 첫 번째. {artist1}의 {song1}. 두 번째. {artist2}의 {song2}. 어느 곡이 맞나요? 첫 번째 또는 두 번째라고 말해 주세요.',
    'listening': '선택을 듣고 있어요...',
    'failed': '잘 알아듣지 못했어요. 아래에서 올바른 곡을 눌러 주세요.',
  },
  'zh': {
    'prompt': 'Reczt 找到两个很可能的结果。第一首。{artist1} 的 {song1}。第二首。{artist2} 的 {song2}。哪一首是正确的？请说第一首或第二首。',
    'listening': '正在聆听你的选择…',
    'failed': '没有听清。请点击下面正确的歌曲。',
  },
  'hi': {
    'prompt': 'Reczt को दो अच्छे संभावित गाने मिले। पहला। {artist1} का {song1}। दूसरा। {artist2} का {song2}। कौन सा सही था? पहला या दूसरा कहें।',
    'listening': 'आपकी पसंद सुन रहा है...',
    'failed': 'मैं समझ नहीं पाया। नीचे सही गाने पर टैप करें।',
  },
  'ru': {
    'prompt': 'Reczt нашёл два хороших варианта. Первый: {song1}, исполнитель {artist1}. Второй: {song2}, исполнитель {artist2}. Какой вариант правильный? Скажите первый или второй.',
    'listening': 'Слушаю ваш выбор...',
    'failed': 'Не удалось распознать ответ. Нажмите на правильную песню ниже.',
  },
  'tr': {
    'prompt': 'Reczt iki güçlü eşleşme buldu. Birinci: {artist1} tarafından {song1}. İkinci: {artist2} tarafından {song2}. Hangisi doğruydu? Birinci veya ikinci deyin.',
    'listening': 'Seçiminiz dinleniyor...',
    'failed': 'Yanıtınızı anlayamadım. Aşağıdaki doğru şarkıya dokunun.',
  },
  'ar': {
    'prompt': 'وجد Reczt نتيجتين قويتين. الأولى: {song1} لـ {artist1}. الثانية: {song2} لـ {artist2}. أيهما الصحيح؟ قل الأولى أو الثانية.',
    'listening': 'جارٍ الاستماع إلى اختيارك...',
    'failed': 'لم أفهم اختيارك. اضغط على الأغنية الصحيحة أدناه.',
  },
  'nl': {
    'prompt': 'Reczt vond twee goede matches. Eerste: {song1}, van {artist1}. Tweede: {song2}, van {artist2}. Welke was juist? Zeg eerste of tweede.',
    'listening': 'Ik luister naar je keuze...',
    'failed': 'Ik heb dat niet verstaan. Tik hieronder op het juiste nummer.',
  },
  'pl': {
    'prompt': 'Reczt znalazł dwa dobre dopasowania. Pierwszy: {song1}, wykonawca {artist1}. Drugi: {song2}, wykonawca {artist2}. Który był właściwy? Powiedz pierwszy albo drugi.',
    'listening': 'Słucham Twojego wyboru...',
    'failed': 'Nie udało mi się zrozumieć. Dotknij właściwego utworu poniżej.',
  },
};

class MyApp extends StatelessWidget {
  final String currentLang;
  final Color seedColor;
  
  const MyApp({super.key, this.currentLang = 'en', this.seedColor = Colors.deepPurple});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: Locale(currentLang),
      theme: ThemeData(
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.dark,
        ),
      ),
      themeMode: ThemeMode.system,
      home: const AudioRecorderScreen(),
    );
  }
}


// --------------------------------------------------------------------
// 📍 COMPACT ACOUSTIC LOCATION USAGE
// --------------------------------------------------------------------
// Reczt stores one compact bucket per approximate place (~100 m) and
// increments its use count instead of saving one permanent record per mic use.

const String _acousticUsageKey = 'acoustic_location_usage_v3';
const String _acousticUsageMigratedKey =
    'acoustic_location_usage_v3_migrated';

String _acousticBucketKey(double lat, double lng) =>
    '${lat.toStringAsFixed(3)},${lng.toStringAsFixed(3)}';

class _AcousticLocationUsage {
  _AcousticLocationUsage({
    required this.latitude,
    required this.longitude,
    required this.count,
    this.lastUsed,
  });

  double latitude;
  double longitude;
  int count;
  DateTime? lastUsed;

  String get bucketKey => _acousticBucketKey(latitude, longitude);

  Map<String, dynamic> toJson() => <String, dynamic>{
        'lat': latitude,
        'lng': longitude,
        'count': count,
        if (lastUsed != null) 'last_used': lastUsed!.toIso8601String(),
      };

  static _AcousticLocationUsage? fromRaw(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final lat = decoded['lat'];
      final lng = decoded['lng'];
      if (lat is! num || lng is! num) return null;
      final rawCount = decoded['count'];
      return _AcousticLocationUsage(
        latitude: lat.toDouble(),
        longitude: lng.toDouble(),
        count: rawCount is num ? max(1, rawCount.toInt()) : 1,
        lastUsed: DateTime.tryParse(
          (decoded['last_used'] ?? decoded['timestamp'] ?? '').toString(),
        ),
      );
    } catch (_) {
      return null;
    }
  }
}

Future<void> _saveAcousticLocationUsage(
  SharedPreferences prefs,
  Iterable<_AcousticLocationUsage> usages,
) async {
  final sorted = usages.toList()
    ..sort((a, b) => b.count.compareTo(a.count));
  await prefs.setStringList(
    _acousticUsageKey,
    sorted.map((usage) => jsonEncode(usage.toJson())).toList(),
  );
}

Future<List<_AcousticLocationUsage>> _loadAcousticLocationUsage(
  SharedPreferences prefs,
) async {
  final compactRaw = prefs.getStringList(_acousticUsageKey) ?? <String>[];
  final compact = compactRaw
      .map(_AcousticLocationUsage.fromRaw)
      .whereType<_AcousticLocationUsage>()
      .toList();

  if (prefs.getBool(_acousticUsageMigratedKey) ?? false) {
    return compact;
  }

  // If compact data already exists, prefer it rather than risking a second
  // migration after an interrupted run.
  if (compact.isNotEmpty) {
    await prefs.remove('acoustic_mic_locations');
    await prefs.remove('acoustic_memories');
    await prefs.setBool(_acousticUsageMigratedKey, true);
    return compact;
  }

  final buckets = <String, _AcousticLocationUsage>{};
  final micSessionIds = <String>{};
  final micEvents = <Map<String, dynamic>>[];

  void addUsage(
    double lat,
    double lng, {
    int increment = 1,
    DateTime? timestamp,
  }) {
    final key = _acousticBucketKey(lat, lng);
    final safeIncrement = max(1, increment);
    final existing = buckets[key];

    if (existing == null) {
      buckets[key] = _AcousticLocationUsage(
        latitude: lat,
        longitude: lng,
        count: safeIncrement,
        lastUsed: timestamp,
      );
      return;
    }

    final oldCount = existing.count;
    final newCount = oldCount + safeIncrement;
    existing.latitude =
        ((existing.latitude * oldCount) + (lat * safeIncrement)) / newCount;
    existing.longitude =
        ((existing.longitude * oldCount) + (lng * safeIncrement)) / newCount;
    existing.count = newCount;
    if (timestamp != null &&
        (existing.lastUsed == null || timestamp.isAfter(existing.lastUsed!))) {
      existing.lastUsed = timestamp;
    }
  }

  final micRaw =
      prefs.getStringList('acoustic_mic_locations') ?? <String>[];
  for (final raw in micRaw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) continue;
      final latValue = decoded['lat'];
      final lngValue = decoded['lng'];
      if (latValue is! num || lngValue is! num) continue;

      final sessionId = decoded['session_id']?.toString() ?? '';
      final timestamp =
          DateTime.tryParse(decoded['timestamp']?.toString() ?? '');
      final rawCount = decoded['count'];
      final increment = rawCount is num ? rawCount.toInt() : 1;

      if (sessionId.isNotEmpty) micSessionIds.add(sessionId);
      micEvents.add(<String, dynamic>{
        'lat': latValue.toDouble(),
        'lng': lngValue.toDouble(),
        'time': timestamp,
      });

      addUsage(
        latValue.toDouble(),
        lngValue.toDouble(),
        increment: increment,
        timestamp: timestamp,
      );
    } catch (_) {}
  }

  final memoryRaw =
      prefs.getStringList('acoustic_memories') ?? <String>[];
  for (final raw in memoryRaw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) continue;
      final latValue = decoded['lat'];
      final lngValue = decoded['lng'];
      if (latValue is! num || lngValue is! num) continue;

      final lat = latValue.toDouble();
      final lng = lngValue.toDouble();
      final sessionId = decoded['session_id']?.toString() ?? '';
      final timestamp =
          DateTime.tryParse(decoded['timestamp']?.toString() ?? '');

      if (sessionId.isNotEmpty && micSessionIds.contains(sessionId)) {
        continue;
      }

      if (sessionId.isEmpty && timestamp != null) {
        final sameLegacyEvent = micEvents.any((mic) {
          final micTime = mic['time'];
          final micLat = mic['lat'];
          final micLng = mic['lng'];
          if (micTime is! DateTime || micLat is! double || micLng is! double) {
            return false;
          }
          final samePlace =
              (micLat - lat).abs() < 0.0001 && (micLng - lng).abs() < 0.0001;
          return samePlace &&
              micTime.difference(timestamp).inSeconds.abs() <= 90;
        });
        if (sameLegacyEvent) continue;
      }

      addUsage(lat, lng, timestamp: timestamp);
    } catch (_) {}
  }

  final migrated = buckets.values.toList();
  await _saveAcousticLocationUsage(prefs, migrated);

  // Remove the old duplicate-heavy location lists after migration.
  await prefs.remove('acoustic_mic_locations');
  await prefs.remove('acoustic_memories');
  await prefs.setBool(_acousticUsageMigratedKey, true);

  return migrated;
}

Future<void> _recordAcousticLocationUse(
  SharedPreferences prefs,
  double latitude,
  double longitude,
) async {
  final usages = await _loadAcousticLocationUsage(prefs);
  final key = _acousticBucketKey(latitude, longitude);
  final now = DateTime.now();

  _AcousticLocationUsage? existing;
  for (final usage in usages) {
    if (usage.bucketKey == key) {
      existing = usage;
      break;
    }
  }

  if (existing == null) {
    usages.add(
      _AcousticLocationUsage(
        latitude: latitude,
        longitude: longitude,
        count: 1,
        lastUsed: now,
      ),
    );
  } else {
    final oldCount = existing.count;
    final newCount = oldCount + 1;
    existing.latitude =
        ((existing.latitude * oldCount) + latitude) / newCount;
    existing.longitude =
        ((existing.longitude * oldCount) + longitude) / newCount;
    existing.count = newCount;
    existing.lastUsed = now;
  }

  await _saveAcousticLocationUsage(prefs, usages);
}

class _AcousticUsagePin {
  const _AcousticUsagePin({
    required this.offset,
    required this.count,
  });

  final Offset offset;
  final int count;

  @override
  bool operator ==(Object other) =>
      other is _AcousticUsagePin &&
      other.offset == offset &&
      other.count == count;

  @override
  int get hashCode => Object.hash(offset, count);
}

enum EnvironmentMode {
  // ACRCloud humming/cover recognition generally benefits from a longer
  // melodic sample. Reczt still stops early when it has captured enough
  // usable singing, but these are the safe maximum listen windows.
  quiet(duration: 8, icon: Icons.king_bed, key: 'quiet_room'),
  loud(duration: 10, icon: Icons.volume_up, key: 'loud_room'),
  Outdoors(duration: 12, icon: Icons.forest, key: 'Outdoors');

  final int duration;
  final IconData icon;
  final String key;

  const EnvironmentMode({
    required this.duration,
    required this.icon,
    required this.key,
  });
}

/// Normalized candidate shape used by the app regardless of whether your
/// backend returns its existing flattened response or raw-ish ACRCloud humming
/// metadata. Scores are normalized to 0.0-1.0 when present.
class _SongMatchCandidate {
  final Map<String, dynamic> raw;
  final String title;
  final String artist;
  final double? confidence;
  final double? rankingScore;
  final String? genre;
  final String? emotion;
  final String? spotifyUrl;
  final String? appleMusicUrl;
  final String? coverUrl;

  const _SongMatchCandidate({
    required this.raw,
    required this.title,
    required this.artist,
    required this.confidence,
    this.rankingScore,
    this.genre,
    this.emotion,
    this.spotifyUrl,
    this.appleMusicUrl,
    this.coverUrl,
  });

  double? get effectiveScore => rankingScore ?? confidence;

  factory _SongMatchCandidate.fromMap(Map<String, dynamic> item) {
    String title = (item['title'] ?? item['name'] ?? '').toString().trim();

    String artist = '';
    final dynamic rawArtist = item['artist'];
    if (rawArtist != null) {
      artist = rawArtist.toString().trim();
    }
    if (artist.isEmpty && item['artists'] is List) {
      final artists = item['artists'] as List;
      if (artists.isNotEmpty) {
        final first = artists.first;
        if (first is Map) {
          artist = (first['name'] ?? '').toString().trim();
        } else {
          artist = first.toString().trim();
        }
      }
    }

    double? score;
    for (final key in const [
      'confidence',
      'score',
      'humming_score',
      'hummingScore',
      'match_score',
      'confidence_score',
      'matchConfidence',
      'acrcloud_score',
      'similarity',
    ]) {
      final dynamic value = item[key];
      if (value == null) continue;
      final parsed =
          value is num ? value.toDouble() : double.tryParse(value.toString());
      if (parsed != null) {
        final normalizedScore = parsed > 1.0 ? parsed / 100.0 : parsed;
        score = normalizedScore.clamp(0.0, 1.0).toDouble();
        break;
      }
    }

    double? rankingScore;
    for (final key in const ['selection_score', 'ranking_score']) {
      final dynamic value = item[key];
      if (value == null) continue;
      final parsed =
          value is num ? value.toDouble() : double.tryParse(value.toString());
      if (parsed != null) {
        final normalizedScore = parsed > 1.0 ? parsed / 100.0 : parsed;
        rankingScore = normalizedScore.clamp(0.0, 1.0).toDouble();
        break;
      }
    }

    String? genre;
    final dynamic rawGenre = item['genre'];
    if (rawGenre != null && rawGenre.toString().trim().isNotEmpty) {
      genre = _normalizeGenre(rawGenre.toString());
    } else if (item['genres'] is List && (item['genres'] as List).isNotEmpty) {
      final first = (item['genres'] as List).first;
      final value = first is Map ? first['name'] : first;
      if (value != null) genre = _normalizeGenre(value.toString());
    }

    final String? emotion = item['emotion']?.toString();

    String? spotifyUrl = item['spotify_url']?.toString();
    String? appleMusicUrl = item['apple_music_url']?.toString();
    String? coverUrl =
        (item['cover_url'] ?? item['album_art'] ?? item['artwork_url'])?.toString();

    final externalMetadata = item['external_metadata'];
    if (externalMetadata is Map) {
      final spotify = externalMetadata['spotify'];
      if ((spotifyUrl == null || spotifyUrl.isEmpty) && spotify is Map) {
        final track = spotify['track'];
        final id = track is Map ? track['id'] : spotify['id'];
        if (id != null && id.toString().isNotEmpty) {
          spotifyUrl = 'https://open.spotify.com/track/${id.toString()}';
        }
      }
      final apple = externalMetadata['apple_music'];
      if ((appleMusicUrl == null || appleMusicUrl.isEmpty) && apple is Map) {
        final url = apple['url'] ?? apple['link'];
        if (url != null) appleMusicUrl = url.toString();
      }
    }

    artist = _sanitizeArtistName(artist);

    return _SongMatchCandidate(
      raw: item,
      title: title.isEmpty ? 'Unknown Title' : title,
      artist: artist.isEmpty ? 'Unknown Artist' : artist,
      confidence: score,
      rankingScore: rankingScore,
      genre: genre,
      emotion: emotion,
      spotifyUrl: spotifyUrl,
      appleMusicUrl: appleMusicUrl,
      coverUrl: coverUrl,
    );
  }
}

List<Map<String, dynamic>> _extractRecognitionResults(Map<String, dynamic> data) {
  final direct = data['results'];
  if (direct is List) {
    return direct
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  final metadata = data['metadata'];
  if (metadata is Map) {
    final humming = metadata['humming'];
    if (humming is List) {
      return humming
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    final music = metadata['music'];
    if (music is List) {
      return music
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
  }

  final humming = data['humming'];
  if (humming is List) {
    return humming
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  return [data];
}

bool _backendResponseSucceeded(Map<String, dynamic> data) {
  if (data['success'] == true) return true;
  final status = data['status'];
  if (status is Map) {
    final code = status['code'];
    if (code == 0 || code?.toString() == '0') return true;
  }
  return data['results'] is List ||
      data['metadata'] is Map ||
      data['humming'] is List;
}


bool _isSafeQueuedBackgroundMatch(
  List<_SongMatchCandidate> candidates,
  EnvironmentMode mode,
) {
  if (candidates.isEmpty) return false;

  final top = candidates.first;
  final topConfidence = top.confidence ?? 0.0;
  final topScore = top.effectiveScore ?? topConfidence;

  final double minimumScore;
  switch (mode) {
    case EnvironmentMode.quiet:
      minimumScore = 0.52;
      break;
    case EnvironmentMode.loud:
      minimumScore = 0.56;
      break;
    case EnvironmentMode.Outdoors:
      minimumScore = 0.58;
      break;
  }

  if (topConfidence < 0.46 || topScore < minimumScore) {
    return false;
  }

  if (top.artist == 'Unknown Artist' && topScore < 0.72) {
    return false;
  }

  if (candidates.length > 1) {
    final secondScore =
        candidates[1].effectiveScore ?? candidates[1].confidence ?? 0.0;
    final gap = topScore - secondScore;

    if (secondScore >= 0.30 && topScore < 0.82 && gap < 0.10) {
      return false;
    }
  }

  return true;
}

class AudioRecorderScreen extends StatefulWidget {
  const AudioRecorderScreen({super.key});

  @override
  State<AudioRecorderScreen> createState() => _AudioRecorderScreenState();
}

class _AudioRecorderScreenState extends State<AudioRecorderScreen> with WidgetsBindingObserver {

  static const MethodChannel _siriChannel =
      MethodChannel('com.handsfreefinder/siri');

  @override
  void initState() {
    super.initState();
    AudioPlayer.global.setAudioContext(AudioContext(
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.playAndRecord,
        options: {
          AVAudioSessionOptions.defaultToSpeaker,
          AVAudioSessionOptions.mixWithOthers,
          AVAudioSessionOptions.allowBluetooth,
          AVAudioSessionOptions.allowBluetoothA2DP,
        },
      ),
    ));

    WidgetsBinding.instance.addObserver(this);

    _audioRecorder = AudioRecorder();
    _dingPlayer = AudioPlayer();

    if (!kIsWeb && Platform.isIOS) {
      _initOfflineUploadBridge();
    }

    unawaited(_loadStartupState());

    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((results) {
      if (!results.contains(ConnectivityResult.none)) {
        unawaited(_checkPendingOfflineQueue());
      }
    });

    if (!kIsWeb) {
      // One MethodChannel handler owns every Siri entry point. Registering a
      // second handler on the same channel replaces the first one.
      unawaited(_initSiriListener());
      unawaited(_checkColdStartSiri());
    }
  }
  
  String _getDisplayStatusText() {
    if (_customStatusText != null) {
      return _customStatusText!;
    }
    if (_isRecording) {
      if (!_voiceDetected && _voiceWaitSeconds < _maxVoiceWaitSeconds) {
        return t('waiting_for_voice');
      }
      final signalText = _currentAmplitudeDb >= _voiceThresholdDb
          ? t('signal_good')
          : t('sing_louder');
      return '$signalText • ${_secondsRemaining}s';
    }
    return t(_statusTextKey);
  }

  Future<void> _checkColdStartSiri() async {
    final prefs = await SharedPreferences.getInstance();
    final bool launchedFromSiri = prefs.getBool('launchedFromSiri') ?? false;

    if (launchedFromSiri) {
      await prefs.setBool('launchedFromSiri', false);
      unawaited(_checkAndStartSiriRecording());
    }
  }

  Future<void> _checkAndStartSiriRecording() async {
    try {
      final dynamic result = await _siriChannel.invokeMethod('checkSiriTrigger');
      if (result == true) {
        await Future.delayed(const Duration(milliseconds: 800));

        if (await _audioRecorder.hasPermission()) {
          if (mounted && !_isRecording) {
            unawaited(_startRecording());
          }
        }
      }
    } catch (e) {
      debugPrint('=== DEBUG ERROR: $e ===');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _countdownTimer?.cancel();
    _enhancedSearchTimer?.cancel();
    _amplitudeSubscription?.cancel();
    _connectivitySubscription?.cancel();
    if (!kIsWeb) {
      _siriChannel.setMethodCallHandler(null);
      if (Platform.isIOS) {
        _recztOfflineQueueChannel.setMethodCallHandler(null);
      }
    }
    _audioRecorder.dispose();
    _dingPlayer.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_checkAndStartSiriRecording());
        unawaited(_handleQueuedRecognitionOnResume());
      });
    }
  }

  Future<void> _handleQueuedRecognitionOnResume() async {
    await _importServerOfflineResults();
    await _checkPendingOfflineQueue();
  }

  void _initOfflineUploadBridge() {
    _recztOfflineQueueChannel.setMethodCallHandler((call) async {
      if (call.method == 'offlineResultReady') {
        // Don't replace an in-progress foreground result. The native result
        // remains persisted until drainCompletedResults is called, so it can be
        // imported safely on the next resume/startup instead.
        if (_isRecording || _isLoading) return;
        await _importServerOfflineResults();
      }
    });
  }

  late final AudioPlayer _dingPlayer;
  late final AudioRecorder _audioRecorder;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  StreamSubscription<Amplitude>? _amplitudeSubscription;

  bool _isRecording = false;
  bool _isStoppingRecording = false;
  bool _isLoading = false;
  bool _autoPlayEnabled = true;
  bool _offlineQueueProcessing = false;

  // Live microphone quality state. This drives the animated voice meter and
  // lets the countdown wait briefly for the user to actually begin singing.
  double _micLevel = 0.0;
  double _currentAmplitudeDb = -60.0;
  bool _voiceDetected = false;
  int _voiceWaitSeconds = 0;
  int _usableVoiceMilliseconds = 0;
  bool _autoStopRequested = false;
  static const int _maxVoiceWaitSeconds = 4;

  // Retry / ambiguous-result state. Top guesses are only surfaced when
  // Auto Play is OFF so hands-free use is never interrupted.
  String? _lastFailedAudioPath;
  String? _pendingGuessAudioPath;
  List<_SongMatchCandidate> _topGuesses = <_SongMatchCandidate>[];
  // Most first-use testing happens indoors, so start in Quiet by default.
  // A saved user choice still overrides this during startup.
  EnvironmentMode _selectedMode = EnvironmentMode.quiet;
  int _secondsRemaining = 8;
  Timer? _countdownTimer;
  Timer? _enhancedSearchTimer;

  String _preferredMusicApp = 'spotify';
  String _selectedLanguage = 'en';
  Color _themeSeedColor = Colors.deepPurple;

  final Map<String, String> _languages = {
    'en': '🇺🇸 English',
    'es': '🇪🇸 Español',
    'fr': '🇫🇷 Français',
    'de': '🇩🇪 Deutsch',
    'it': '🇮🇹 Italiano',
    'pt': '🇧🇷 Português',
    'ja': '🇯🇵 日本語',
    'ko': '🇰🇷 한국어',
    'zh': '🇨🇳 中文',
    'hi': '🇮🇳 हिन्दी',
    'ru': '🇷🇺 Русский',
    'tr': '🇹🇷 Türkçe',
    'ar': '🇸🇦 العربية',
    'nl': '🇳🇱 Nederlands',
    'pl': '🇵🇱 Polski',
  };

  String _statusTextKey = 'initial_status';
  String? _customStatusText;

  String? _songTitle;
  String? _artist;
  String? _spotifyUrl;
  String? _appleMusicUrl;
  String? _albumArtUrl;
  bool _lastResultWasOffline = false;
  Position? _sessionLocation;
  final String _backendUrl = recztRecognitionBackendUrl;

  String t(String key) {
    return localizedStrings[_selectedLanguage]?[key] ??
        localizedStrings['en']![key] ??
        key;
  }

  String _voiceT(String key) {
    return _voiceChoiceStrings[_selectedLanguage]?[key] ??
        _voiceChoiceStrings['en']?[key] ??
        key;
  }

  void _startEnhancedSearchIndicator({required bool isFromOfflineQueue}) {
    _enhancedSearchTimer?.cancel();
    if (isFromOfflineQueue) return;

    // The backend starts with its fastest recognition path. If the request is
    // still running after a few seconds, the slower/high-accuracy fallback is
    // likely being consulted. This status keeps that extra accuracy from
    // looking like a frozen search without adding another network round trip.
    _enhancedSearchTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted || !_isLoading || _isRecording) return;
      setState(() {
        _customStatusText = t('enhanced_search');
      });
    });
  }

  void _cancelEnhancedSearchIndicator() {
    _enhancedSearchTimer?.cancel();
    _enhancedSearchTimer = null;
  }

  Future<void> _showLegalDocument({
    required String title,
    required String body,
    String onlineUrl = '',
  }) async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          actionsAlignment: MainAxisAlignment.center,
          actionsOverflowAlignment: OverflowBarAlignment.center,
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: SelectableText(
                body,
                style: const TextStyle(fontSize: 13.5, height: 1.4),
              ),
            ),
          ),
          actions: [
            if (onlineUrl.trim().isNotEmpty)
              TextButton(
                onPressed: () async {
                  final uri = Uri.tryParse(onlineUrl);
                  if (uri != null && await canLaunchUrl(uri)) {
                    await launchUrl(
                      uri,
                      mode: LaunchMode.externalApplication,
                    );
                  }
                },
                child: Text(t('view_online')),
              ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(t('legal_close')),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showLegalNoticeIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();

    // On a brand-new install, preferences are chosen first so Reczt can show
    // this notice in the user's selected app language.
    final hasInitialPreferences =
        prefs.getString('preferred_music_app') != null &&
        prefs.getString('preferred_language') != null;
    if (!hasInitialPreferences) return;

    final acceptedVersion = prefs.getString('legal_notice_version');
    if (acceptedVersion == recztLegalNoticeVersion) return;

    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            title: Text(t('legal_notice_title')),
            actionsAlignment: MainAxisAlignment.center,
            actionsOverflowAlignment: OverflowBarAlignment.center,
            content: Text(
              t('legal_notice_body'),
              style: const TextStyle(height: 1.35),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  _showLegalDocument(
                    title: t('privacy_policy'),
                    body: _recztPrivacyPolicyText,
                    onlineUrl: recztPrivacyPolicyUrl,
                  );
                },
                child: Text(t('privacy_policy')),
              ),
              TextButton(
                onPressed: () {
                  _showLegalDocument(
                    title: t('terms_of_use'),
                    body: _recztTermsOfUseText,
                    onlineUrl: recztTermsOfUseUrl,
                  );
                },
                child: Text(t('terms_of_use')),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(t('legal_accept')),
              ),
            ],
          ),
        );
      },
    );

    if (accepted == true) {
      await prefs.setString(
        'legal_notice_version',
        recztLegalNoticeVersion,
      );
    }
  }

  Future<void> _showUserManualIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();

    // The first-run preferences dialog is shown before the legal notice. Wait
    // until those preferences exist so the manual is presented in the user's
    // chosen language and theme.
    final hasInitialPreferences =
        prefs.getString('preferred_music_app') != null &&
        prefs.getString('preferred_language') != null;
    if (!hasInitialPreferences) return;

    // The manual should appear only after the current legal notice has been
    // accepted, so it never competes with the required legal dialog.
    final acceptedLegalVersion = prefs.getString('legal_notice_version');
    if (acceptedLegalVersion != recztLegalNoticeVersion) return;

    final shownManualVersion = prefs.getString('user_manual_version');
    if (shownManualVersion == recztUserManualVersion) return;

    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    await _showUserManualDialog(context);
    await prefs.setString('user_manual_version', recztUserManualVersion);
  }

  Future<void> _loadStartupState() async {
    await _loadSavedMode();
    await _loadPreferences();
    await _showLegalNoticeIfNeeded();
    await _showUserManualIfNeeded();
    if (mounted) {
      await _importServerOfflineResults();
      await _checkPendingOfflineQueue();
    }
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final savedApp = prefs.getString('preferred_music_app');
    final savedLang = prefs.getString('preferred_language');
    final int? savedColorValue = prefs.getInt('theme_seed_color');
    final bool? savedAutoPlay = prefs.getBool('auto_play_enabled');

    if (!mounted) return;
    setState(() {
      _preferredMusicApp = savedApp ?? 'spotify';
      _selectedLanguage = savedLang ?? 'en';
      _autoPlayEnabled = savedAutoPlay ?? true;
      if (savedColorValue != null) {
        _themeSeedColor = Color(savedColorValue);
      }
    });

    if (savedApp == null || savedLang == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showPreferencesDialog();
      });
    }
  }

  Future<void> _savePreferences(String musicApp, String lang, Color seedColor, bool autoPlay) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('preferred_music_app', musicApp);
    await prefs.setString('preferred_language', lang);
    await prefs.setInt('theme_seed_color', seedColor.toARGB32());
    await prefs.setBool('auto_play_enabled', autoPlay);
    if (autoPlay) {
      unawaited(_prepareHandsFreeVoiceChoice());
    }

    setState(() {
      _preferredMusicApp = musicApp;
      _selectedLanguage = lang;
      _themeSeedColor = seedColor;
      _autoPlayEnabled = autoPlay;
    });

    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => MyApp(currentLang: lang, seedColor: seedColor),
        ),
        (route) => false,
      );
    }
  }

  void _showPreferencesDialog() {
    String tempApp = _preferredMusicApp;
    String tempLang = _selectedLanguage;
    Color tempColor = _themeSeedColor;
    bool tempAutoPlay = _autoPlayEnabled;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: Text(t('settings_title')),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t('pref_music_app'),
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    RadioListTile<String>(
                      title: const Text('Spotify'),
                      value: 'spotify',
                      groupValue: tempApp,
                      onChanged: (val) => setModalState(() => tempApp = val!),
                    ),
                    RadioListTile<String>(
                      title: const Text('Apple Music'),
                      value: 'apple_music',
                      groupValue: tempApp,
                      onChanged: (val) => setModalState(() => tempApp = val!),
                    ),
                    const Divider(),
                    SwitchListTile(
                      title: Text(t('auto_play_title')),
                      value: tempAutoPlay,
                      onChanged: (val) => setModalState(() => tempAutoPlay = val),
                    ),
                    const Divider(),
                    const SizedBox(height: 8),
                    Text(t('pref_lang'),
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    DropdownButton<String>(
                      isExpanded: true,
                      value: _languages.containsKey(tempLang) ? tempLang : 'en',
                      items: _languages.entries.map((entry) {
                        return DropdownMenuItem<String>(
                          value: entry.key,
                          child: Text(entry.value),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() => tempLang = val);
                        }
                      },
                    ),
                    const Divider(),
                    const SizedBox(height: 8),
                    Text(t('theme_title'),
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    DropdownButton<Color>(
                      isExpanded: true,
                      value: [Colors.deepPurple, Colors.blue, Colors.teal, Colors.orange]
                          .firstWhere(
                            (c) => c.toARGB32() == tempColor.toARGB32(),
                            orElse: () => Colors.deepPurple,
                          ),
                      items: [
                        DropdownMenuItem(value: Colors.deepPurple, child: Text(t('theme_purple'))),
                        DropdownMenuItem(value: Colors.blue, child: Text(t('theme_blue'))),
                        DropdownMenuItem(value: Colors.teal, child: Text(t('theme_emerald'))),
                        DropdownMenuItem(value: Colors.orange, child: Text(t('theme_orange'))),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() => tempColor = val);
                        }
                      },
                    ),
                    const Divider(),
                    const SizedBox(height: 4),
                    Center(
                      child: Text(
                        t('legal_privacy'),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Center(
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 2,
                        runSpacing: 0,
                        children: [
                          TextButton(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () {
                              _showLegalDocument(
                                title: t('privacy_policy'),
                                body: _recztPrivacyPolicyText,
                                onlineUrl: recztPrivacyPolicyUrl,
                              );
                            },
                            child: Text(
                              t('privacy_policy'),
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                          const Text('•', style: TextStyle(fontSize: 10)),
                          TextButton(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () {
                              _showLegalDocument(
                                title: t('terms_of_use'),
                                body: _recztTermsOfUseText,
                                onlineUrl: recztTermsOfUseUrl,
                              );
                            },
                            child: Text(
                              t('terms_of_use'),
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                          const Text('•', style: TextStyle(fontSize: 10)),
                          TextButton(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () {
                              showLicensePage(
                                context: context,
                                applicationName: 'Reczt',
                              );
                            },
                            child: Text(
                              t('open_source_licenses'),
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(t('cancel')),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _savePreferences(tempApp, tempLang, tempColor, tempAutoPlay);
                  },
                  child: Text(t('save')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _initSiriListener() async {
    _siriChannel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onSiriTrigger':
        case 'triggerSiriRecord':
          _triggerAutoRecordingFromSiri();
          break;
        case 'startSiriRecognition':
          await _checkAndStartSiriRecording();
          break;
      }
    });

    try {
      final url = await _siriChannel.invokeMethod<String>('getInitialUrl');
      if (url != null && url.isNotEmpty) {
        _triggerAutoRecordingFromSiri();
        return;
      }
      final triggered =
          await _siriChannel.invokeMethod<bool>('checkSiriTrigger');
      if (triggered == true) {
        _triggerAutoRecordingFromSiri();
      }
    } catch (e) {
      debugPrint('Siri listener unavailable: $e');
    }
  }

  void _triggerAutoRecordingFromSiri() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!_isRecording && !_isLoading && mounted) {
        unawaited(_startRecording(playDing: true));
      }
    });
  }

  Future<void> _loadSavedMode() async {
    final prefs = await SharedPreferences.getInstance();
    final savedIndex = prefs.getInt('selected_environment_mode');
    if (savedIndex != null &&
        savedIndex >= 0 &&
        savedIndex < EnvironmentMode.values.length &&
        mounted) {
      setState(() {
        _selectedMode = EnvironmentMode.values[savedIndex];
        _secondsRemaining = _selectedMode.duration;
      });
    }
  }

  Future<void> _saveMode(EnvironmentMode mode) async {
    setState(() {
      _selectedMode = mode;
      _secondsRemaining = mode.duration;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('selected_environment_mode', mode.index);
  }

  Future<void> _deleteLocalFile(String? path) async {
    if (kIsWeb || path == null || path.isEmpty) return;
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('Could not delete temporary audio file: $e');
    }
  }

  Future<String?> _preserveAudioClip(String tempPath) async {
    if (kIsWeb) return null;
    try {
      final source = File(tempPath);
      if (!await source.exists()) return null;
      final appDir = await getApplicationDocumentsDirectory();
      final String fileName =
          'clip_${DateTime.now().microsecondsSinceEpoch}.wav';
      final File savedFile =
          await source.copy('${appDir.path}/$fileName');
      return savedFile.path;
    } catch (e) {
      debugPrint('Error preserving audio clip: $e');
      return null;
    }
  }

  Future<void> _saveToHistory(
    String songEntry, {
    String? title,
    String? artist,
    String? audioPath,
    String? albumCover,
    String? genre,
    String? emotion,
    String? spotifyUrl,
    String? appleMusicUrl,
    bool foundOffline = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> history = prefs.getStringList('song_history') ?? [];

    final Map<String, dynamic> historyObj = {
      'song': songEntry,
      'title': title ?? '',
      'artist': artist ?? '',
      'audioPath': audioPath ?? '',
      'albumCover': albumCover ?? '',
      'genre': _normalizeGenre(genre),
      'emotion': _normalizeEmotion(emotion),
      'spotifyUrl': spotifyUrl ?? '',
      'appleMusicUrl': appleMusicUrl ?? '',
      'foundOffline': foundOffline,
    };

    history.insert(0, jsonEncode(historyObj));
    await prefs.setStringList('song_history', history);
  }

  Future<void> _playSingleDing() async {
    try {
      await _dingPlayer.stop();
      await _dingPlayer.setVolume(1.0);
      await _dingPlayer.play(AssetSource('ding.mp3'));
    } catch (e) {
      debugPrint('Error playing ding sound: $e');
    }
  }

  Future<void> _playErrorCue() async {
    // Use a real bundled cue. SystemSoundType.click can be extremely quiet or
    // effectively inaudible on some iPhones, which is why the previous error
    // sound could appear not to play even though no asset was missing.
    try {
      await _dingPlayer.stop();
      await _dingPlayer.setVolume(0.72);
      await _dingPlayer.play(AssetSource('reczt_error.wav'));
    } catch (e) {
      debugPrint('Error playing Reczt error cue: $e');
      try {
        await SystemSound.play(SystemSoundType.alert);
      } catch (_) {}
    }

    try {
      await HapticFeedback.lightImpact();
    } catch (_) {}
  }

  double get _voiceThresholdDb {
    switch (_selectedMode) {
      case EnvironmentMode.quiet:
        return -45.0;
      case EnvironmentMode.loud:
        return -35.0;
      case EnvironmentMode.Outdoors:
        return -37.0;
    }
  }

  int get _targetUsableVoiceMilliseconds {
    switch (_selectedMode) {
      case EnvironmentMode.quiet:
        return 8000;
      case EnvironmentMode.loud:
        return 10000;
      case EnvironmentMode.Outdoors:
        return 12000;
    }
  }

  double get _dynamicConfidenceThreshold {
    // ACRCloud humming scores are commonly returned on a 0-1 scale. We keep
    // these thresholds intentionally moderate and only use them to decide
    // whether to ASK the user among multiple guesses when Auto Play is off.
    switch (_selectedMode) {
      case EnvironmentMode.quiet:
        return 0.58;
      case EnvironmentMode.loud:
        return 0.62;
      case EnvironmentMode.Outdoors:
        return 0.64;
    }
  }

  RecordConfig _recordConfigForCurrentEnvironment() {
    // Keep the existing environment-aware capture profile. The backend now
    // cross-checks raw-vs-trimmed audio and overlapping melodic windows, so we
    // improve recognition without making an untested microphone-DSP change
    // right before App Store release.
    return RecordConfig(
      encoder: AudioEncoder.wav,
      sampleRate: 44100,
      numChannels: 1,
      autoGain: true,
      noiseSuppress: _selectedMode != EnvironmentMode.quiet,
      echoCancel: _selectedMode == EnvironmentMode.loud,
    );
  }

  void _startAmplitudeMonitoring() {
    _amplitudeSubscription?.cancel();
    _amplitudeSubscription = _audioRecorder
        .onAmplitudeChanged(const Duration(milliseconds: 140))
        .listen((amplitude) {
      if (!mounted || !_isRecording) return;

      final double rawDb = amplitude.current.isFinite
          ? amplitude.current
          : -60.0;
      final double normalized =
          ((rawDb + 60.0) / 50.0).clamp(0.0, 1.0).toDouble();
      final bool usableVoice = rawDb >= _voiceThresholdDb;

      if (usableVoice) {
        _voiceDetected = true;
        _usableVoiceMilliseconds += 140;
      }

      setState(() {
        _currentAmplitudeDb = rawDb;
        _micLevel = normalized;
      });

      if (!_autoStopRequested &&
          _voiceDetected &&
          _usableVoiceMilliseconds >= _targetUsableVoiceMilliseconds) {
        _autoStopRequested = true;
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted && _isRecording && !_isStoppingRecording) {
            unawaited(_stopAndSendRecording());
          }
        });
      }
    });
  }

  void _startSmartCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || !_isRecording) {
        timer.cancel();
        return;
      }

      // Do not waste the first few seconds if the user triggered Reczt before
      // they were ready to sing. After four seconds we count down anyway so
      // noisy environments can never leave recording open indefinitely.
      if (!_voiceDetected && _voiceWaitSeconds < _maxVoiceWaitSeconds) {
        setState(() {
          _voiceWaitSeconds++;
        });
        return;
      }

      if (_secondsRemaining > 0) {
        setState(() {
          _secondsRemaining--;
        });
      }
      if (_secondsRemaining <= 0) {
        timer.cancel();
        if (!_isStoppingRecording) {
          unawaited(_stopAndSendRecording());
        }
      }
    });
  }

  bool _hasMeaningfulAmbiguity(List<_SongMatchCandidate> candidates) {
    if (candidates.length < 2) return false;

    final top = candidates[0].effectiveScore;
    final second = candidates[1].effectiveScore;
    if (top == null || second == null) return false;

    // Do not interrupt hands-free playback for a second candidate that is
    // itself weaker than the 28% hands-free acceptance floor.
    if (second < 0.28) return false;

    final gap = (top - second).abs();
    return top < _dynamicConfidenceThreshold ||
        (top < 0.92 && gap < 0.08);
  }

  bool _shouldOfferTopGuesses(List<_SongMatchCandidate> candidates) {
    if (_autoPlayEnabled || candidates.isEmpty) return false;
    final top = candidates.first.effectiveScore;
    if (top == null) return false;

    if (candidates.length > 1 && top < _dynamicConfidenceThreshold) {
      return true;
    }
    return _hasMeaningfulAmbiguity(candidates);
  }

  int _candidateEvidenceCount(_SongMatchCandidate candidate) {
    final raw = candidate.raw;
    int parse(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.round();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    final evidence = parse(raw['evidence_count']);
    final acrVotes = parse(raw['acr_pass_votes']);
    return max(evidence, acrVotes);
  }

  /// Voice choice should be reserved for two genuinely plausible songs.
  /// ACRCloud can occasionally return two unrelated low-confidence guesses; the
  /// old flow would read those aloud simply because they were close to each other.
  /// That feels much worse than admitting uncertainty, especially in Auto Play.
  bool _shouldSpeakHandsFreeChoices(
    List<_SongMatchCandidate> candidates,
  ) {
    if (candidates.length < 2) return false;

    final top = candidates[0];
    final second = candidates[1];
    final topScore = top.effectiveScore;
    final secondScore = second.effectiveScore;
    if (topScore == null || secondScore == null) return false;

    double topFloor;
    double secondFloor;
    switch (_selectedMode) {
      case EnvironmentMode.quiet:
        topFloor = 0.50;
        secondFloor = 0.38;
        break;
      case EnvironmentMode.loud:
        topFloor = 0.53;
        secondFloor = 0.40;
        break;
      case EnvironmentMode.Outdoors:
        topFloor = 0.55;
        secondFloor = 0.42;
        break;
    }

    // Independent agreement from multiple ACR passes / recognition sources is
    // meaningful evidence, so supported candidates get a modest allowance.
    if (_candidateEvidenceCount(top) >= 2) topFloor -= 0.04;
    if (_candidateEvidenceCount(second) >= 2) secondFloor -= 0.025;

    if (topScore < topFloor || secondScore < secondFloor) return false;

    // Unknown-artist guesses need substantially stronger evidence before Reczt
    // speaks them aloud as a real option.
    if ((top.artist == 'Unknown Artist' && topScore < 0.70) ||
        (second.artist == 'Unknown Artist' && secondScore < 0.66)) {
      return false;
    }

    return true;
  }

  String get _voiceChoiceLocale {
    const locales = <String, String>{
      'en': 'en-US',
      'es': 'es-ES',
      'fr': 'fr-FR',
      'de': 'de-DE',
      'it': 'it-IT',
      'pt': 'pt-BR',
      'ja': 'ja-JP',
      'ko': 'ko-KR',
      'zh': 'zh-CN',
      'hi': 'hi-IN',
      'ru': 'ru-RU',
      'tr': 'tr-TR',
      'ar': 'ar-SA',
      'nl': 'nl-NL',
      'pl': 'pl-PL',
    };
    return locales[_selectedLanguage] ?? 'en-US';
  }

  Map<String, List<String>> get _voiceChoiceOrdinals {
    const words = <String, Map<String, List<String>>>{
      'en': {'first': ['first', 'one', 'number one'], 'second': ['second', 'two', 'number two']},
      'es': {'first': ['primera', 'primero', 'uno', 'número uno'], 'second': ['segunda', 'segundo', 'dos', 'número dos']},
      'fr': {'first': ['première', 'premier', 'un', 'numéro un'], 'second': ['deuxième', 'seconde', 'deux', 'numéro deux']},
      'de': {'first': ['erste', 'erster', 'eins', 'nummer eins'], 'second': ['zweite', 'zweiter', 'zwei', 'nummer zwei']},
      'it': {'first': ['prima', 'primo', 'uno', 'numero uno'], 'second': ['seconda', 'secondo', 'due', 'numero due']},
      'pt': {'first': ['primeira', 'primeiro', 'um', 'número um'], 'second': ['segunda', 'segundo', 'dois', 'número dois']},
      'ja': {'first': ['1番目', '一番目', '最初', '1'], 'second': ['2番目', '二番目', '二つ目', '2']},
      'ko': {'first': ['첫 번째', '첫번째', '하나', '1번'], 'second': ['두 번째', '두번째', '둘', '2번']},
      'zh': {'first': ['第一首', '第一个', '第一'], 'second': ['第二首', '第二个', '第二']},
      'hi': {'first': ['पहला', 'पहली', 'एक', 'नंबर एक'], 'second': ['दूसरा', 'दूसरी', 'दो', 'नंबर दो']},
      'ru': {'first': ['первый', 'первая', 'один', 'номер один'], 'second': ['второй', 'вторая', 'два', 'номер два']},
      'tr': {'first': ['birinci', 'ilk', 'bir', 'numara bir'], 'second': ['ikinci', 'iki', 'numara iki']},
      'ar': {'first': ['الأولى', 'الأول', 'واحد', 'رقم واحد'], 'second': ['الثانية', 'الثاني', 'اثنان', 'رقم اثنين']},
      'nl': {'first': ['eerste', 'één', 'een', 'nummer één'], 'second': ['tweede', 'twee', 'nummer twee']},
      'pl': {'first': ['pierwszy', 'pierwsza', 'jeden', 'numer jeden'], 'second': ['drugi', 'druga', 'dwa', 'numer dwa']},
    };
    return words[_selectedLanguage] ?? words['en']!;
  }

  Future<void> _prepareHandsFreeVoiceChoice() async {
    if (kIsWeb || !Platform.isIOS) return;
    try {
      await _recztVoiceChoiceChannel.invokeMethod<bool>('prepare');
    } catch (e) {
      debugPrint('Voice choice preparation unavailable: $e');
    }
  }

  String _buildVoiceChoicePrompt(
    _SongMatchCandidate first,
    _SongMatchCandidate second,
  ) {
    return _voiceT('prompt')
        .replaceAll('{song1}', first.title)
        .replaceAll(
          '{artist1}',
          first.artist == 'Unknown Artist' ? t('unknown_artist') : first.artist,
        )
        .replaceAll('{song2}', second.title)
        .replaceAll(
          '{artist2}',
          second.artist == 'Unknown Artist' ? t('unknown_artist') : second.artist,
        );
  }

  Future<int?> _askHandsFreeSongChoice(
    List<_SongMatchCandidate> candidates,
  ) async {
    if (candidates.length < 2 || kIsWeb || !Platform.isIOS) return null;

    final first = candidates[0];
    final second = candidates[1];
    final ordinals = _voiceChoiceOrdinals;

    if (mounted) {
      setState(() {
        _customStatusText = _voiceT('listening');
      });
    }

    try {
      final choice = await _recztVoiceChoiceChannel.invokeMethod<int>(
        'askSongChoice',
        <String, dynamic>{
          'prompt': _buildVoiceChoicePrompt(first, second),
          'locale': _voiceChoiceLocale,
          'firstPhrases': <String>[...ordinals['first']!, first.title],
          'secondPhrases': <String>[...ordinals['second']!, second.title],
        },
      );
      if (choice == 0 || choice == 1) return choice;
    } catch (e) {
      debugPrint('Hands-free song choice unavailable: $e');
    }
    return null;
  }

  Future<void> _importServerOfflineResults() async {
    if (kIsWeb || !Platform.isIOS) return;

    List<dynamic> completed = const <dynamic>[];
    try {
      completed =
          await _recztOfflineQueueChannel.invokeMethod<List<dynamic>>(
                'drainCompletedResults',
              ) ??
              const <dynamic>[];
    } catch (e) {
      debugPrint('Could not read completed offline uploads: $e');
      return;
    }

    if (completed.isEmpty) return;

    for (final raw in completed) {
      try {
        final dynamic decoded =
            raw is String ? jsonDecode(raw) : raw;
        if (decoded is! Map) continue;

        final item = Map<String, dynamic>.from(decoded);
        if (!_backendResponseSucceeded(item)) continue;

        final queuedPath = (item['queued_path'] ?? '').toString();
        final candidate = _SongMatchCandidate.fromMap(item);

        if (candidate.title.trim().isEmpty ||
            candidate.title == 'Unknown Title') {
          continue;
        }

        String? preservedPath;
        if (queuedPath.isNotEmpty) {
          preservedPath = await _preserveAudioClip(queuedPath);
        }

        await _finalizeCandidate(
          candidate,
          audioPath: preservedPath,
          isFromOfflineQueue: true,
          allowAutoPlay: false,
          notifyQueuedMatch: false,
        );

        final prefs = await SharedPreferences.getInstance();
        final queue =
            prefs.getStringList('pending_offline_songs') ?? <String>[];
        queue.remove(queuedPath);
        await prefs.setStringList('pending_offline_songs', queue);

        if (queuedPath.isNotEmpty) {
          await _deleteLocalFile(queuedPath);
        }
      } catch (e) {
        debugPrint('Could not import server-side offline result: $e');
      }
    }
  }

  Future<bool> _scheduleIOSOfflineUpload(String path) async {
    if (kIsWeb || !Platform.isIOS || path.trim().isEmpty) return false;

    try {
      final scheduled =
          await _recztOfflineQueueChannel.invokeMethod<bool>(
            'scheduleUpload',
            <String, dynamic>{
              'filePath': path,
              'backendUrl': recztRecognitionBackendUrl,
              'language': _selectedLanguage,
              'environment': _selectedMode.name.toLowerCase(),
            },
          );
      return scheduled ?? false;
    } catch (e) {
      debugPrint('Could not schedule iOS offline upload: $e');
      return false;
    }
  }

  Future<String?> _saveToOfflineQueue(String sourcePath) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> pendingQueue =
        prefs.getStringList('pending_offline_songs') ?? [];

    String queuedPath = sourcePath;
    if (!kIsWeb) {
      try {
        final source = File(sourcePath);
        if (!await source.exists()) return null;
        final appDir = await getApplicationDocumentsDirectory();
        queuedPath =
            '${appDir.path}/offline_${DateTime.now().microsecondsSinceEpoch}.wav';
        await source.copy(queuedPath);
      } catch (e) {
        debugPrint('Error persisting offline recording: $e');
        return null;
      }
    }

    if (!pendingQueue.contains(queuedPath)) {
      pendingQueue.add(queuedPath);
      await prefs.setStringList('pending_offline_songs', pendingQueue);
    }

    // On iOS, hand the file to a native background URLSession immediately.
    // Background sessions wait for connectivity automatically, so this can be
    // scheduled while the phone is still offline. The server performs the
    // recognition after the upload reaches it.
    if (!kIsWeb && Platform.isIOS) {
      unawaited(_scheduleIOSOfflineUpload(queuedPath));
    }

    return queuedPath;
  }

  Future<void> _checkPendingOfflineQueue() async {
    if (_offlineQueueProcessing || _isRecording || _isLoading) return;

    _offlineQueueProcessing = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> queue =
          prefs.getStringList('pending_offline_songs') ?? <String>[];
      if (queue.isEmpty) return;

      // iOS uses native file-based background URLSession uploads. Scheduling is
      // idempotent: AppDelegate ignores a path that already has an active task.
      if (!kIsWeb && Platform.isIOS) {
        final freshQueue = List<String>.from(queue);
        for (final path in List<String>.from(queue)) {
          final file = File(path);
          if (!await file.exists()) {
            freshQueue.remove(path);
            continue;
          }
          await _scheduleIOSOfflineUpload(path);
        }
        if (freshQueue.length != queue.length) {
          await prefs.setStringList('pending_offline_songs', freshQueue);
        }
        return;
      }

      // Non-iOS fallback: process queued items while Reczt is in the foreground.
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult.contains(ConnectivityResult.none)) return;

      while (mounted && !_isRecording && !_isLoading) {
        final latestPrefs = await SharedPreferences.getInstance();
        final latestQueue =
            latestPrefs.getStringList('pending_offline_songs') ?? <String>[];
        if (latestQueue.isEmpty) break;

        final path = latestQueue.first;
        if (!kIsWeb && !await File(path).exists()) {
          latestQueue.removeAt(0);
          await latestPrefs.setStringList(
            'pending_offline_songs',
            latestQueue,
          );
          continue;
        }

        final online = await Connectivity().checkConnectivity();
        if (online.contains(ConnectivityResult.none)) break;

        final processed =
            await _sendAudioToBackend(path, isFromOfflineQueue: true);
        if (!processed) break;

        final refreshedPrefs = await SharedPreferences.getInstance();
        final refreshedQueue =
            refreshedPrefs.getStringList('pending_offline_songs') ??
                <String>[];
        refreshedQueue.remove(path);
        await refreshedPrefs.setStringList(
          'pending_offline_songs',
          refreshedQueue,
        );
        await _deleteLocalFile(path);
      }
    } catch (e) {
      debugPrint('Error checking offline queue: $e');
    } finally {
      _offlineQueueProcessing = false;
    }
  }

  Future<void> _clearAmbiguousResult({bool deleteAudio = true}) async {
    final path = _pendingGuessAudioPath;
    _pendingGuessAudioPath = null;
    if (mounted) {
      setState(() {
        _topGuesses = <_SongMatchCandidate>[];
      });
    } else {
      _topGuesses = <_SongMatchCandidate>[];
    }
    if (deleteAudio) {
      await _deleteLocalFile(path);
    }
  }

  Future<void> _stopAndSendRecording() async {
    if (_isStoppingRecording || !_isRecording) return;
    _isStoppingRecording = true;
    _countdownTimer?.cancel();
    await _amplitudeSubscription?.cancel();
    _amplitudeSubscription = null;
    await _endLiveSingingTracking();

    try {
      if (mounted) {
        setState(() {
          _isRecording = false;
          _micLevel = 0.0;
          _isLoading = true;
          _statusTextKey = 'searching';
          _customStatusText = null;
        });
      }

      final path = await _audioRecorder.stop();

      if (path != null && path.isNotEmpty) {
        final connectivityResult = await Connectivity().checkConnectivity();
        if (connectivityResult.contains(ConnectivityResult.none)) {
          final queuedPath = await _saveToOfflineQueue(path);
          await _deleteLocalFile(path);
          if (mounted) {
            setState(() {
              _isLoading = false;
              _customStatusText = queuedPath != null
                  ? t('offline_saved')
                  : t('connection_failed');
            });
          }
          return;
        }

        final bool processed = await _sendAudioToBackend(path);
        if (processed) {
          if (_lastFailedAudioPath == path) _lastFailedAudioPath = null;
          await _deleteLocalFile(path);
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _customStatusText = t('error_empty_path');
          });
        }
        unawaited(_playErrorCue());
      }
    } catch (e) {
      debugPrint('Error stopping recording: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _customStatusText = t('error_stopping');
        });
      }
      unawaited(_playErrorCue());
    } finally {
      _isStoppingRecording = false;
    }
  }

  Future<void> _retryLastRecording() async {
    final String? path = _lastFailedAudioPath;
    if (path == null || path.isEmpty || _isLoading || _isRecording) return;
    if (!kIsWeb && !await File(path).exists()) {
      _lastFailedAudioPath = null;
      if (mounted) setState(() {});
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
        _customStatusText = null;
        _statusTextKey = 'searching';
      });
    }

    final bool processed = await _sendAudioToBackend(path);
    if (processed) {
      _lastFailedAudioPath = null;
      await _deleteLocalFile(path);
      if (mounted) setState(() {});
    }
  }

  Future<bool> _sendAudioToBackend(
    String path, {
    bool isFromOfflineQueue = false,
  }) async {
    final uri = Uri.parse(_backendUrl);
    final request = http.MultipartRequest('POST', uri);
    request.fields['language'] = _selectedLanguage;
    // Kept for backend compatibility. Backend v3 intentionally uses only
    // conservative silence trimming before its multi-pass recognition.
    request.fields['vocal_isolation'] = 'true';
    request.fields['environment'] = _selectedMode.name;
    // Use a more forgiving backend floor only for genuine hands-free Auto Play.
    request.fields['auto_play'] =
        (_autoPlayEnabled && !isFromOfflineQueue).toString();
    request.fields['background_queue'] = isFromOfflineQueue.toString();

    _startEnhancedSearchIndicator(isFromOfflineQueue: isFromOfflineQueue);

    try {
      if (kIsWeb) {
        final sourceResponse =
            await http.get(Uri.parse(path)).timeout(const Duration(seconds: 12));
        final bytes = sourceResponse.bodyBytes;
        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            bytes,
            filename: 'recording.wav',
          ),
        );
      } else {
        request.files.add(await http.MultipartFile.fromPath('file', path));
      }

      // Backend v3 can run several ACR windows and a lyric cross-check on an
      // ambiguous clip, so allow a little more time before treating it as failed.
      final streamedResponse =
          await request.send().timeout(const Duration(seconds: 32));
      final response = await http.Response.fromStream(streamedResponse)
          .timeout(const Duration(seconds: 8));

      if (mounted && !isFromOfflineQueue) {
        setState(() {
          _isLoading = false;
        });
      }

      if (response.statusCode != 200) {
        final bool retryable =
            response.statusCode >= 500 || response.statusCode == 429;
        if (mounted) {
          setState(() {
            _customStatusText =
                '${t('server_error')}: ${response.statusCode}';
            if (!isFromOfflineQueue) {
              _lastFailedAudioPath = retryable ? path : null;
            }
          });
        }
        unawaited(_playErrorCue());
        // For an offline queue, permanent 4xx responses are consumed so a bad
        // item cannot block every recording behind it. Retryable errors stay queued.
        return !retryable;
      }

      final dynamic decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        throw FormatException('Recognition response was not an object');
      }
      final data = Map<String, dynamic>.from(decoded);

      if (!_backendResponseSucceeded(data)) {
        final bool retryable = data['retryable'] == true;
        if (mounted) {
          setState(() {
            _customStatusText = t('error_no_lyrics');
            if (!isFromOfflineQueue && retryable) {
              // Keep the exact clip so the existing Retry button can resubmit it
              // without forcing the user to sing again.
              _lastFailedAudioPath = path;
            }
          });
        }
        if (!isFromOfflineQueue) {
          unawaited(_playErrorCue());
        }

        // Offline unresolved recordings stay queued. Foreground retryable
        // recognition failures keep their file as well; non-retryable "no match"
        // responses are consumed normally.
        if (isFromOfflineQueue) return false;
        return !retryable;
      }

      final List<Map<String, dynamic>> rawResults =
          _extractRecognitionResults(data);

      final filteredResults =
          LanguageMatcher.filterResultsByLanguage<Map<String, dynamic>>(
        results: rawResults,
        selectedLanguage: _selectedLanguage,
        getLanguage: (item) => item['language']?.toString() ?? '',
        mode: _selectedMode,
      );

      final candidates = filteredResults
          .where(LanguageMatcher.isValidOriginalSong)
          .map(_SongMatchCandidate.fromMap)
          .where((candidate) =>
              candidate.title.trim().isNotEmpty &&
              candidate.title != 'Unknown Title')
          .toList();

      candidates.sort((a, b) {
        final aScore = a.effectiveScore;
        final bScore = b.effectiveScore;
        if (aScore == null && bScore == null) return 0;
        if (aScore == null) return 1;
        if (bScore == null) return -1;
        return bScore.compareTo(aScore);
      });

      if (isFromOfflineQueue &&
          !_isSafeQueuedBackgroundMatch(candidates, _selectedMode)) {
        debugPrint(
          'Queued recognition held for retry because the match was not '
          'strong enough for unattended background acceptance.',
        );
        return false;
      }

      if (candidates.isEmpty) {
        if (mounted) {
          setState(() {
            _songTitle = null;
            _artist = null;
            _spotifyUrl = null;
            _appleMusicUrl = null;
            _topGuesses = <_SongMatchCandidate>[];
            _customStatusText = t('error_no_lyrics');
          });
        }
        unawaited(_playErrorCue());
        return true;
      }

      // Resolve ambiguity differently depending on interaction mode.
      // Manual mode uses the tappable Top Guesses card.
      // Auto Play remains hands-free: Reczt reads the top two choices aloud
      // and listens for "first" or "second". If that fails, the card appears
      // as a safe fallback instead of auto-playing a questionable match.
      if (!isFromOfflineQueue) {
        final ambiguous = _hasMeaningfulAmbiguity(candidates);

        if (_autoPlayEnabled && ambiguous) {
          final preservedPath = await _preserveAudioClip(path);
          final visibleChoices = candidates.take(2).toList();

          // Do not have the voice confidently read two garbage guesses merely
          // because their scores happen to be close. Preserve the exact clip for
          // Retry and tell the user we were not confident enough instead.
          if (!_shouldSpeakHandsFreeChoices(visibleChoices)) {
            if (mounted) {
              setState(() {
                _isLoading = false;
                _songTitle = null;
                _artist = null;
                _spotifyUrl = null;
                _appleMusicUrl = null;
                _topGuesses = <_SongMatchCandidate>[];
                _pendingGuessAudioPath = null;
                _lastFailedAudioPath = preservedPath;
                _customStatusText = t('no_valid_match');
              });
            } else {
              _lastFailedAudioPath = preservedPath;
            }
            unawaited(_playErrorCue());
            return true;
          }

          final spokenChoice =
              await _askHandsFreeSongChoice(visibleChoices);

          if (spokenChoice != null &&
              spokenChoice >= 0 &&
              spokenChoice < visibleChoices.length) {
            await _finalizeCandidate(
              visibleChoices[spokenChoice],
              audioPath: preservedPath,
              isFromOfflineQueue: false,
              allowAutoPlay: true,
            );
            unawaited(_checkPendingOfflineQueue());
            return true;
          }

          if (mounted) {
            setState(() {
              _isLoading = false;
              _songTitle = null;
              _artist = null;
              _spotifyUrl = null;
              _appleMusicUrl = null;
              _topGuesses = visibleChoices;
              _pendingGuessAudioPath = preservedPath;
              _customStatusText = _voiceT('failed');
            });
          }
          return true;
        }

        if (_shouldOfferTopGuesses(candidates)) {
          final preservedPath = await _preserveAudioClip(path);
          if (mounted) {
            setState(() {
              _isLoading = false;
              _songTitle = null;
              _artist = null;
              _spotifyUrl = null;
              _appleMusicUrl = null;
              _topGuesses = candidates.take(3).toList();
              _pendingGuessAudioPath = preservedPath;
              _customStatusText = t('top_guesses_subtitle');
            });
          }
          return true;
        }
      }

      final preservedPath = await _preserveAudioClip(path);
      await _finalizeCandidate(
        candidates.first,
        audioPath: preservedPath,
        isFromOfflineQueue: isFromOfflineQueue,
        allowAutoPlay: _autoPlayEnabled && !isFromOfflineQueue,
      );

      if (!isFromOfflineQueue) {
        unawaited(_checkPendingOfflineQueue());
      }
      return true;
    } on TimeoutException {
      if (mounted) {
        setState(() {
          if (!isFromOfflineQueue) {
            _isLoading = false;
            _lastFailedAudioPath = path;
          }
          _customStatusText = t('search_timed_out');
        });
      }
      unawaited(_playErrorCue());
      return false;
    } catch (e) {
      debugPrint('Recognition request failed: $e');
      if (mounted) {
        setState(() {
          if (!isFromOfflineQueue) {
            _isLoading = false;
            _lastFailedAudioPath = path;
          }
          _customStatusText = t('connection_failed');
        });
      }
      unawaited(_playErrorCue());
      return false;
    } finally {
      _cancelEnhancedSearchIndicator();
    }
  }

  Future<void> _selectTopGuess(_SongMatchCandidate candidate) async {
    if (_isLoading) return;
    final audioPath = _pendingGuessAudioPath;
    _pendingGuessAudioPath = null;

    if (mounted) {
      setState(() {
        _isLoading = true;
        _topGuesses = <_SongMatchCandidate>[];
        _customStatusText = null;
      });
    }

    await _finalizeCandidate(
      candidate,
      audioPath: audioPath,
      isFromOfflineQueue: false,
      allowAutoPlay: _autoPlayEnabled,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _finalizeCandidate(
    _SongMatchCandidate candidate, {
    required String? audioPath,
    required bool isFromOfflineQueue,
    required bool allowAutoPlay,
    bool notifyQueuedMatch = true,
  }) async {
    final String title = candidate.title;
    final String rawCandidateArtist =
        candidate.artist == 'Unknown Artist' ? '' : candidate.artist;
    String resolvedArtist = _sanitizeArtistName(rawCandidateArtist);
    String displayArtist = resolvedArtist.isNotEmpty
        ? resolvedArtist
        : t('unknown_artist');

    if (mounted) {
      setState(() {
        _songTitle = title;
        _artist = displayArtist;
        _spotifyUrl = candidate.spotifyUrl;
        _appleMusicUrl = candidate.appleMusicUrl;
        _albumArtUrl = candidate.coverUrl;
        _lastResultWasOffline = isFromOfflineQueue;
        _topGuesses = <_SongMatchCandidate>[];
        _statusTextKey = 'match_found';
        _customStatusText = null;
        _isLoading = false;
      });
    }

    // Hands-free mode should feel immediate. Once Reczt has accepted the match,
    // open the user's music app before doing nonessential artwork/analytics I/O.
    if (allowAutoPlay && _autoPlayEnabled) {
      if (_preferredMusicApp == 'apple_music' &&
          candidate.appleMusicUrl != null &&
          candidate.appleMusicUrl!.isNotEmpty) {
        unawaited(_openMusicUrl(candidate.appleMusicUrl!));
      } else if (candidate.spotifyUrl != null &&
          candidate.spotifyUrl!.isNotEmpty) {
        unawaited(_openSpotifyNative(candidate.spotifyUrl!));
      }
    }

    final String candidateGenre = _normalizeGenre(candidate.genre);
    final String? candidateCover =
        (candidate.coverUrl != null && candidate.coverUrl!.trim().isNotEmpty)
            ? candidate.coverUrl
            : null;

    // The optimized backend normally already sends both genre and artwork.
    // Avoid repeating the same catalog lookup unless one of those fields is
    // actually missing; this removes a redundant network request from the
    // normal recognition path.
    _SongLookupMetadata metadata = const _SongLookupMetadata();
    if (candidateCover == null ||
        candidateGenre.isEmpty ||
        resolvedArtist.isEmpty) {
      metadata = await fetchSongMetadataForSong(title, resolvedArtist);
    }

    if (resolvedArtist.isEmpty) {
      resolvedArtist = _fallbackArtistForTitle(title);
    }
    if (resolvedArtist.isEmpty) {
      resolvedArtist = _sanitizeArtistName(metadata.artist);
    }
    displayArtist = resolvedArtist.isNotEmpty
        ? resolvedArtist
        : t('unknown_artist');

    final String? albumArt = candidateCover ?? metadata.artworkUrl;
    final String genre = candidateGenre.isNotEmpty
        ? candidateGenre
        : _normalizeGenre(metadata.genre);
    final String emotion = _resolveSongEmotion(
      title: title,
      artist: displayArtist,
      backendEmotion: candidate.emotion,
      genre: genre,
    );

    if (mounted &&
        (albumArt != _albumArtUrl || displayArtist != _artist)) {
      setState(() {
        _albumArtUrl = albumArt;
        _artist = displayArtist;
      });
    }

    await _saveToHistory(
      '$title - $displayArtist',
      title: title,
      artist: displayArtist,
      audioPath: audioPath,
      albumCover: albumArt,
      genre: genre,
      emotion: emotion,
      spotifyUrl: candidate.spotifyUrl,
      appleMusicUrl: candidate.appleMusicUrl,
      foundOffline: isFromOfflineQueue,
    );

    await recordSessionToAnalytics(
      songTitle: title,
      artistName: displayArtist,
      primaryEmotion: emotion,
      genre: genre,
      latitude: _sessionLocation?.latitude,
      longitude: _sessionLocation?.longitude,
    );

    await _recordSuccessfulRecognitionAndMaybeRequestReview();

    if (isFromOfflineQueue && notifyQueuedMatch) {
      unawaited(showQueuedSongFoundNotification(_selectedLanguage));
    }
  }

  Future<void> recordSessionToAnalytics({
    required String songTitle,
    required String artistName,
    required String primaryEmotion,
    required String genre,
    double? latitude,
    double? longitude,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    // If the user manually cleared the Vibe Match card, the next successful
    // recognition makes it eligible to generate a fresh recommendation.
    await prefs.remove('analytics_playlist_user_cleared_v1');

    final int totalSongs = (prefs.getInt('analytics_total_songs') ?? 0) + 1;
    await prefs.setInt('analytics_total_songs', totalSongs);

    final normalizedEmotion = _normalizeEmotion(primaryEmotion);
    final emotionKey =
        normalizedEmotion.isEmpty ? 'happy' : normalizedEmotion;
    final int emotionCount =
        (prefs.getInt('analytics_emotion_$emotionKey') ?? 0) + 1;
    await prefs.setInt('analytics_emotion_$emotionKey', emotionCount);

    // Artist counts are permanent and case-insensitive, so "Coldplay" and
    // "coldplay" cannot accidentally become separate artists.
    final String? artistJson = prefs.getString('analytics_artist_counts');
    Map<String, dynamic> artistMap = {};
    if (artistJson != null) {
      try {
        artistMap = jsonDecode(artistJson) as Map<String, dynamic>;
      } catch (_) {}
    }

    final cleanedArtist = _sanitizeArtistName(artistName);
    if (cleanedArtist.isNotEmpty &&
        cleanedArtist.toLowerCase() != t('unknown_artist').toLowerCase()) {
      String storageKey = cleanedArtist;
      for (final existing in artistMap.keys) {
        if (existing.trim().toLowerCase() == cleanedArtist.toLowerCase()) {
          storageKey = existing;
          break;
        }
      }
      artistMap[storageKey] = ((artistMap[storageKey] ?? 0) as num).toInt() + 1;
      await prefs.setString('analytics_artist_counts', jsonEncode(artistMap));
    }

    // Never create an "Other" bucket. If the backend does not provide genre,
    // the catalog lookup in _finalizeCandidate gets a real genre first.
    final normalizedGenre = _normalizeGenre(genre);
    if (normalizedGenre.isNotEmpty) {
      final String? genreJson = prefs.getString('analytics_genre_counts');
      Map<String, dynamic> genreMap = {};
      if (genreJson != null) {
        try {
          genreMap = jsonDecode(genreJson) as Map<String, dynamic>;
        } catch (_) {}
      }
      genreMap[normalizedGenre] =
          ((genreMap[normalizedGenre] ?? 0) as num).toInt() + 1;
      // Remove legacy broad buckets so they never reappear in the chart.
      genreMap.remove('other');
      genreMap.remove('Other');
      await prefs.setString('analytics_genre_counts', jsonEncode(genreMap));
    }

    // A streak only needs one entry per calendar day.
    final List<String> sessionDates =
        prefs.getStringList('analytics_session_dates') ?? [];
    final now = DateTime.now();
    final dayStamp = DateTime(now.year, now.month, now.day).toIso8601String();
    final hasToday = sessionDates.any((raw) {
      final parsed = DateTime.tryParse(raw);
      return parsed != null &&
          parsed.year == now.year &&
          parsed.month == now.month &&
          parsed.day == now.day;
    });
    if (!hasToday) {
      sessionDates.add(dayStamp);
      await prefs.setStringList('analytics_session_dates', sessionDates);
    }

    // Location usage is recorded once when the microphone starts via
    // _recordAcousticLocationUse(). Keeping it out of successful-song
    // analytics prevents duplicate location storage.
  }

  Future<void> _openSpotifyNative(String url) async {
    String finalUrl = url;
    if (url.startsWith('spotify:track:')) {
      final trackId = url.replaceFirst('spotify:track:', '');
      finalUrl = 'spotify:track:$trackId';
    }
    await _openMusicUrl(finalUrl);
  }

  Future<void> _openMusicUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// Marks the user as actively singing and captures their current location
  /// so the analytics acoustic map can show a live pin.
  Future<void> _beginLiveSingingTracking() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_currently_singing', true);

    // This call also triggers the OS "Allow location while using the app?"
    // prompt the first time the user sings, if permission has not been decided.
    final position = await getCurrentDeviceLocation();

    if (position != null) {
      if (mounted) {
        _sessionLocation = position;
      }

      final encodedPosition = jsonEncode({
        'lat': position.latitude,
        'lng': position.longitude,
        'timestamp': DateTime.now().toIso8601String(),
      });
      await prefs.setStringList('active_singing_locations', [encodedPosition]);

      // One compact lifetime pin per approximate place. Repeated mic uses in
      // roughly the same ~100 m area increment this location's use count.
      await _recordAcousticLocationUse(
        prefs,
        position.latitude,
        position.longitude,
      );
    } else {
      await prefs.remove('active_singing_locations');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t('location_pin_permission')),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _endLiveSingingTracking() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_currently_singing', false);
    await prefs.remove('active_singing_locations');
  }

  Future<void> _startRecording({bool playDing = true}) async {
    if (_isRecording || _isLoading || _isStoppingRecording) return;

    if (!await _audioRecorder.hasPermission()) {
      if (mounted) {
        setState(() {
          _customStatusText = t('mic_denied');
        });
      }
      return;
    }

    // Starting a brand-new search means the user no longer needs an old
    // failed temp file or an unselected ambiguous singing clip.
    final oldFailedPath = _lastFailedAudioPath;
    _lastFailedAudioPath = null;
    await _deleteLocalFile(oldFailedPath);
    await _clearAmbiguousResult(deleteAudio: true);

    if (playDing) {
      await _playSingleDing();
      await Future.delayed(const Duration(milliseconds: 550));
    }

    String filePath = '';
    if (!kIsWeb) {
      final directory = await getTemporaryDirectory();
      filePath =
          '${directory.path}/recording_${DateTime.now().microsecondsSinceEpoch}.wav';
    }

    try {
      await _audioRecorder.start(
        _recordConfigForCurrentEnvironment(),
        path: filePath,
      );

      if (!mounted) return;
      setState(() {
        _isRecording = true;
        _secondsRemaining = _selectedMode.duration;
        _voiceWaitSeconds = 0;
        _voiceDetected = false;
        _usableVoiceMilliseconds = 0;
        _autoStopRequested = false;
        _currentAmplitudeDb = -60.0;
        _micLevel = 0.0;
        _songTitle = null;
        _artist = null;
        _albumArtUrl = null;
        _spotifyUrl = null;
        _appleMusicUrl = null;
        _lastResultWasOffline = false;
        _sessionLocation = null;
        _customStatusText = null;
      });

      unawaited(_beginLiveSingingTracking());
      _startAmplitudeMonitoring();
      _startSmartCountdown();
    } catch (e) {
      debugPrint('Error starting recording: $e');
      if (mounted) {
        setState(() {
          _isRecording = false;
          _customStatusText = t('connection_failed');
        });
      }
      await _deleteLocalFile(filePath);
    }
  }

  Widget _buildVoiceVisualizer(Color color) {
    const multipliers = <double>[0.35, 0.65, 0.9, 0.55, 1.0, 0.55, 0.9, 0.65, 0.35];
    return Semantics(
      label: _getDisplayStatusText(),
      child: SizedBox(
        height: 34,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: multipliers.map((factor) {
            final height = 5.0 + (_micLevel * 25.0 * factor);
            return AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOut,
              width: 4,
              height: height,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildTopGuessesCard() {
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    t('top_guesses_title'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              t('top_guesses_subtitle'),
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            ..._topGuesses.map((candidate) {
              final confidence = candidate.confidence == null
                  ? null
                  : (candidate.confidence! * 100).round();
              final displayArtist = candidate.artist == 'Unknown Artist'
                  ? t('unknown_artist')
                  : candidate.artist;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.12),
                  child: Icon(Icons.music_note, color: color),
                ),
                title: Text(
                  candidate.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  confidence == null
                      ? displayArtist
                      : '$displayArtist • $confidence% ${t('confidence')}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _selectTopGuess(candidate),
              );
            }),
          ],
        ),
      ),
    );
  }

@override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reczt'),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    t('app_title'),
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: Icon(Icons.bar_chart, color: Theme.of(context).colorScheme.primary),
                        tooltip: t('analytics_title'),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AnalyticsPage(lang: _selectedLanguage),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        icon: Icon(Icons.settings, color: Theme.of(context).colorScheme.primary),
                        tooltip: t('settings_title'),
                        onPressed: _showPreferencesDialog,
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        icon: Icon(Icons.history, color: Theme.of(context).colorScheme.primary),
                        tooltip: t('history_title'),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => HistoryPage(lang: _selectedLanguage),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        icon: Icon(Icons.menu_book, color: Theme.of(context).colorScheme.primary),
                        tooltip: t('User Manual'),
                        onPressed: () => unawaited(_showUserManualDialog(context)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 20),
                  Text(
                    t('where_are_you'),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Column(
                    children: EnvironmentMode.values.map((mode) {
                      final isSelected = _selectedMode == mode;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6.0),
                        child: InkWell(
                          onTap: _isRecording || _isLoading
                              ? null
                              : () {
                                  _saveMode(mode);
                                },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? primaryColor.withValues(alpha: 0.12)
                                  : theme.colorScheme.surfaceContainerHighest
                                      .withValues(alpha: isDarkMode ? 0.45 : 0.65),
                              border: Border.all(
                                color: isSelected
                                    ? primaryColor
                                    : theme.colorScheme.outlineVariant,
                                width: isSelected ? 2 : 1,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  mode.icon,
                                  color: isSelected
                                      ? primaryColor
                                      : theme.colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    t(mode.key),
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: isSelected
                                          ? primaryColor
                                          : theme.colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? primaryColor
                                        : theme.colorScheme.surfaceContainerHigh,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${mode.duration}s',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected
                                          ? Colors.white
                                          : theme.colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    _getDisplayStatusText(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (_isRecording) ...[
                    const SizedBox(height: 10),
                    _buildVoiceVisualizer(primaryColor),
                  ],
                  const SizedBox(height: 22),
                  if (_isLoading)
                    const CircularProgressIndicator()
                  else
                    Semantics(
                      button: true,
                      label: _isRecording ? t('stop_recording') : t('listening'),
                      child: GestureDetector(
                        onTap: () {
                          if (_isRecording) {
                            unawaited(_stopAndSendRecording());
                          } else {
                            unawaited(_startRecording(playDing: true));
                          }
                        },
                        child: SizedBox(
                          width: 128,
                          height: 128,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 140),
                                width: 106 + (_isRecording ? _micLevel * 20 : 0),
                                height: 106 + (_isRecording ? _micLevel * 20 : 0),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: (_isRecording ? Colors.red : primaryColor)
                                      .withValues(alpha: _isRecording
                                          ? 0.10 + (_micLevel * 0.12)
                                          : 0.10),
                                ),
                              ),
                              CircleAvatar(
                                radius: 50,
                                backgroundColor:
                                    _isRecording ? Colors.red : primaryColor,
                                child: Icon(
                                  _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                                  size: 50,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (!_isRecording &&
                      !_isLoading &&
                      _lastFailedAudioPath != null) ...[
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () => unawaited(_retryLastRecording()),
                      icon: const Icon(Icons.refresh),
                      label: Text(t('retry_search')),
                    ),
                  ],
                  if (_topGuesses.isNotEmpty) ...[
                    const SizedBox(height: 22),
                    _buildTopGuessesCard(),
                  ],
                  const SizedBox(height: 30),
                  if (_songTitle != null && _artist != null) ...[
                    Card(
                      elevation: 6,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: _lastResultWasOffline
                            ? BorderSide(
                                color: Colors.orange.shade600,
                                width: 2.0,
                              )
                            : BorderSide.none,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.share, color: Theme.of(context).colorScheme.primary),
                                  onPressed: () {
                                    QuickShareHelper.showSongShareSheet(
                                      context,
                                      lang: _selectedLanguage,
                                      title: _songTitle!,
                                      artist: _artist!,
                                      coverUrl: _albumArtUrl,
                                    );
                                  },
                                ),
                              ],
                            ),
                            if (_lastResultWasOffline) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: Colors.orange.shade600,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.cloud_done_outlined,
                                      size: 16,
                                      color: Colors.orange.shade700,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      t('found_offline_badge'),
                                      style: TextStyle(
                                        color: Colors.orange.shade800,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                t('found_offline_detail'),
                                style: TextStyle(
                                  color: Colors.orange.shade800,
                                  fontSize: 12,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 14),
                            ],
                            Icon(Icons.music_note,
                                size: 60, color: Theme.of(context).colorScheme.primary),
                            const SizedBox(height: 12),
                            Text(
                              _songTitle!,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${t('by')} $_artist',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade700,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 20),
                            if (_preferredMusicApp == 'apple_music' &&
                                _appleMusicUrl != null &&
                                _appleMusicUrl!.isNotEmpty)
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFA243C),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 12),
                                ),
                                onPressed: () => _openMusicUrl(_appleMusicUrl!),
                                icon: const Icon(Icons.play_arrow),
                                label: Text(t('open_apple')),
                              )
                            else if (_spotifyUrl != null &&
                                _spotifyUrl!.isNotEmpty)
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1DB954),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 12),
                                ),
                                onPressed: () => _openSpotifyNative(_spotifyUrl!),
                                icon: const Icon(Icons.play_arrow),
                                label: Text(t('open_spotify')),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showUserManualDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final maxContentHeight =
            MediaQuery.of(dialogContext).size.height * 0.66;

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.menu_book,
                color: Theme.of(dialogContext).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(t('User Manual')),
            ],
          ),
          content: SizedBox(
            width: 560,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxContentHeight),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildManualSectionHeader(
                      context: dialogContext,
                      title: t('getting_started'),
                    ),
                    const SizedBox(height: 12),
                    _buildManualStep(
                      step: "1",
                      title: t('step 1'),
                      desc: t('step1_desc'),
                    ),
                    const Divider(height: 20),
                    _buildManualStep(
                      step: "2",
                      title: t('step 2'),
                      desc: t('step2_desc'),
                    ),
                    const Divider(height: 20),
                    _buildManualStep(
                      step: "3",
                      title: t('step 3'),
                      desc: t('step3_desc'),
                    ),
                    const Divider(height: 20),
                    _buildManualStep(
                      step: "4",
                      title: t('step 4'),
                      desc: t('step4_desc'),
                    ),
                    const Divider(height: 20),
                    _buildManualStep(
                      step: "5",
                      title: t('step 5'),
                      desc: t('step5_desc'),
                    ),
                    const Divider(height: 20),
                    _buildManualStep(
                      step: "6",
                      title: t('step 6'),
                      desc: t('step6_desc'),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Divider(),
                    ),
                    _buildManualSectionHeader(
                      context: dialogContext,
                      title: t('explore_more'),
                    ),
                    const SizedBox(height: 12),
                    _buildManualStep(
                      step: "7",
                      title: t('step 7'),
                      desc: t('step7_desc'),
                    ),
                    const Divider(height: 20),
                    _buildManualStep(
                      step: "8",
                      title: t('step 8'),
                      desc: t('step8_desc'),
                    ),
                    const Divider(height: 20),
                    _buildManualStep(
                      step: "9",
                      title: t('step 9'),
                      desc: t('step9_desc'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(t('got it')),
            ),
          ],
        );
      },
    );
  }

  Widget _buildManualSectionHeader({
    required BuildContext context,
    required String title,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Text(
      title,
      style: TextStyle(
        color: colorScheme.primary,
        fontSize: 15,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  Widget _buildManualStep({
    required String step,
    required String title,
    required String desc,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: Theme.of(context).colorScheme.primary,
          child: Text(
            step,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey[300]
                      : Colors.grey[700],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ----------------------------------------------------
// 📊 COMPACT ANALYTICS & STATISTICS PAGE (GRID & LOCALIZED)
// ----------------------------------------------------
class AnalyticsPage extends StatefulWidget {
  final String lang;
  const AnalyticsPage({super.key, required this.lang});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}


class _AnalyticsPageState extends State<AnalyticsPage> {
  int _singingStreak = 0;
  List<String> _topArtists = [];
  late Map<String, int> _genreCounts;
  Map<String, int> _emotionCounts = {};

  bool _isCurrentlySinging = false;
  List<Offset> _livePinLocations = [];
  List<_AcousticUsagePin> _memoryPinLocations = [];
  Timer? _mapRefreshTimer;
  bool _genreBackfillStarted = false;

  String _curatedPlaylistTitle = "";
  String _streamingUrl = "";
  String _majorityEmotion = "Balanced";
  String _countdownText = "";
  String _preferredApp = 'spotify';

  String get preferredPlatform =>
      _preferredApp == 'apple_music' ? 'Apple Music' : 'Spotify';

  String t(String key) {
    return localizedStrings[widget.lang]?[key] ??
        localizedStrings['en']?[key] ??
        key;
  }

  String _genreLabel(String rawGenre) {
    final normalized = _normalizeGenre(rawGenre);
    if (normalized.isEmpty) return '';
    final translated = t(normalized);
    return translated == normalized
        ? _formatGenreLabel(normalized)
        : translated;
  }

  @override
  void initState() {
    super.initState();
    _genreCounts = <String, int>{};
    _curatedPlaylistTitle = t('analyzing');
    _countdownText = t('calculating');
    unawaited(_computeAnalytics());

    // This lightweight refresh lets a Siri-triggered recording update the map
    // while the Analytics page happens to be open.
    _mapRefreshTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => unawaited(_refreshMapPinsOnly()),
    );
  }

  @override
  void dispose() {
    _mapRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _showClearRecztDataDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(t('clear_reczt_data')),
          content: Text(
            t('clear_reczt_data_confirm'),
            style: const TextStyle(height: 1.35),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actionsOverflowAlignment: OverflowBarAlignment.center,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(t('cancel')),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                t('clear_data_action'),
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _clearLocalRecztData();
    }
  }

  Future<void> _showClearAnalyticsSectionDialog({
    required String sectionKey,
    required String sectionLabel,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(t('clear_this_data')),
          content: Text(
            t('clear_this_data_confirm')
                .replaceAll('{section}', sectionLabel),
            style: const TextStyle(height: 1.35),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actionsOverflowAlignment: OverflowBarAlignment.center,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(t('cancel')),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                t('clear'),
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _clearAnalyticsSection(sectionKey);
    }
  }

  Future<void> _clearAnalyticsSection(String sectionKey) async {
    final prefs = await SharedPreferences.getInstance();

    switch (sectionKey) {
      case 'streak':
        await prefs.remove('analytics_session_dates');
        break;

      case 'artist':
        await prefs.setString('analytics_artist_counts', '{}');
        // Prevent the one-time repair path from repopulating the card from
        // older History. New successful songs still accumulate normally.
        await prefs.setBool('analytics_artist_user_cleared_v1', true);
        break;

      case 'playlist':
        for (final key in const <String>[
          'playlist_timestamp',
          'saved_curated_playlist',
          'saved_curated_playlist_profile',
          'saved_curated_playlist_spotify_title',
          'saved_curated_playlist_spotify_url',
          'saved_curated_playlist_apple_title',
          'saved_curated_playlist_apple_url',
          'saved_curated_playlist_apple_personalized',
          'saved_curated_playlist_apple_timestamp',
        ]) {
          await prefs.remove(key);
        }
        // Keep the card intentionally blank until the next successful song.
        await prefs.setBool('analytics_playlist_user_cleared_v1', true);
        break;

      case 'map':
        for (final key in const <String>[
          _acousticUsageKey,
          'acoustic_mic_locations',
          'acoustic_memories',
          'active_singing_locations',
        ]) {
          await prefs.remove(key);
        }
        await prefs.setBool(_acousticUsageMigratedKey, true);
        break;

      case 'genres':
        await prefs.setString('analytics_genre_counts', '{}');
        // Do not refill the cleared chart from pre-clear History.
        await prefs.setBool('analytics_genre_backfill_v2', true);
        await prefs.setBool('analytics_genre_user_cleared_v1', true);
        break;

      case 'emotions':
        for (final key in const ['happy', 'sad', 'hype', 'romantic']) {
          await prefs.setInt('analytics_emotion_$key', 0);
        }
        await prefs.setInt('analytics_emotion_schema_version', 2);
        await prefs.setBool('analytics_emotion_user_cleared_v1', true);
        break;
    }

    await _computeAnalytics(allowGenreBackfill: false);

    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(t('data_box_cleared'))),
      );
  }

  Widget _buildClearableAnalyticsCard({
    required String sectionKey,
    required String sectionLabel,
    required Widget child,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: () => _showClearAnalyticsSectionDialog(
        sectionKey: sectionKey,
        sectionLabel: sectionLabel,
      ),
      child: _buildThemedCard(child: child),
    );
  }

  Future<void> _clearLocalRecztData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Cancel any system-owned iOS background uploads before deleting their
      // source recordings, and discard completed native results waiting to be
      // imported into Flutter.
      if (!kIsWeb && Platform.isIOS) {
        try {
          await _recztOfflineQueueChannel.invokeMethod<void>(
            'cancelAllUploads',
          );
          await _recztOfflineQueueChannel.invokeMethod<void>(
            'clearCompletedResults',
          );
        } catch (e) {
          debugPrint('Could not clear native offline uploads: $e');
        }
      }

      // Capture all known persistent recording paths before their preference
      // entries are removed.
      final audioPaths = <String>{};

      final history = prefs.getStringList('song_history') ?? <String>[];
      for (final raw in history) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is Map) {
            final path = decoded['audioPath']?.toString().trim() ?? '';
            if (path.isNotEmpty) audioPaths.add(path);
          }
        } catch (_) {}
      }

      final queued =
          prefs.getStringList('pending_offline_songs') ?? <String>[];
      audioPaths.addAll(queued.where((path) => path.trim().isNotEmpty));

      if (!kIsWeb) {
        for (final path in audioPaths) {
          try {
            final file = File(path);
            if (await file.exists()) {
              await file.delete();
            }
          } catch (e) {
            debugPrint('Could not delete Reczt audio file: $e');
          }
        }

        // Remove orphaned Reczt-generated persistent WAV files too.
        try {
          final appDir = await getApplicationDocumentsDirectory();
          await for (final entity in appDir.list()) {
            if (entity is! File) continue;
            final name = entity.uri.pathSegments.isEmpty
                ? ''
                : entity.uri.pathSegments.last;
            final isRecztAudio =
                (name.startsWith('clip_') || name.startsWith('offline_')) &&
                name.toLowerCase().endsWith('.wav');
            if (isRecztAudio) {
              try {
                await entity.delete();
              } catch (e) {
                debugPrint('Could not delete orphaned Reczt audio file: $e');
              }
            }
          }
        } catch (e) {
          debugPrint('Could not scan Reczt audio directory: $e');
        }
      }

      // This is a privacy/data reset, not an app-preferences reset. Keep the
      // user's language, music app, theme, Auto Play, environment, and legal
      // acknowledgement while removing user-created Reczt data.
      const directDataKeys = <String>{
        'song_history',
        'pending_offline_songs',
        'acoustic_memories',
        'acoustic_mic_locations',
        _acousticUsageKey,
        _acousticUsageMigratedKey,
        'active_singing_locations',
        'is_currently_singing',
        'playlist_timestamp',
        'saved_curated_playlist',
        'saved_curated_playlist_profile',
        'saved_curated_playlist_spotify_title',
        'saved_curated_playlist_spotify_url',
        'saved_curated_playlist_apple_title',
        'saved_curated_playlist_apple_url',
        'saved_curated_playlist_apple_personalized',
        'saved_curated_playlist_apple_timestamp',
      };

      final keysToRemove = prefs.getKeys().where(
        (key) =>
            directDataKeys.contains(key) ||
            key.startsWith('analytics_'),
      );

      for (final key in keysToRemove.toList()) {
        await prefs.remove(key);
      }

      // Refresh this page immediately from the now-empty user dataset.
      await _computeAnalytics(allowGenreBackfill: false);

      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(t('clear_reczt_data_success'))),
        );
    } catch (e) {
      debugPrint('Error clearing local Reczt data: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(t('clear_reczt_data_error'))),
        );
    }
  }

  Offset _latLngToMapOffset(double lat, double lng) {
    final double dx = ((lng + 180) / 360).clamp(0.0, 1.0);
    final double dy = ((90 - lat) / 180).clamp(0.0, 1.0);
    return Offset(dx, dy);
  }

  Map<String, dynamic> _decodeHistoryAnalyticsEntry(String rawItem) {
    Map<String, dynamic> record = <String, dynamic>{};
    String songText = rawItem;

    if (rawItem.trimLeft().startsWith('{')) {
      try {
        final decoded = jsonDecode(rawItem);
        if (decoded is Map) {
          record = Map<String, dynamic>.from(decoded);
          songText = (record['song'] ?? '').toString();
        }
      } catch (_) {}
    }

    String title = (record['title'] ?? '').toString().trim();
    String artist = (record['artist'] ?? '').toString().trim();

    if ((title.isEmpty || artist.isEmpty) && songText.contains(' - ')) {
      final parts = songText.split(' - ');
      if (title.isEmpty && parts.isNotEmpty) {
        title = parts.first.trim();
      }
      if (artist.isEmpty && parts.length > 1) {
        artist = parts.sublist(1).join(' - ').trim();
      }
    } else if (title.isEmpty) {
      title = songText.trim();
    }

    artist = _sanitizeArtistName(artist);
    if (artist.isEmpty) {
      artist = _fallbackArtistForTitle(title);
    }

    record['title'] = title;
    record['artist'] = artist;
    return record;
  }

  String _canonicalArtistKey(String artist) =>
      artist.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  Future<void> _repairArtistAndEmotionAnalytics(
    SharedPreferences prefs,
  ) async {
    final history = prefs.getStringList('song_history') ?? <String>[];
    if (history.isEmpty) {
      final int emotionSchema =
          prefs.getInt('analytics_emotion_schema_version') ?? 0;
      if (emotionSchema < 2) {
        for (final key in const ['happy', 'sad', 'hype', 'romantic']) {
          await prefs.setInt('analytics_emotion_$key', 0);
        }
        await prefs.setInt('analytics_emotion_schema_version', 2);
      }
      return;
    }

    final Map<String, int> historyArtistCounts = <String, int>{};
    final Map<String, String> artistDisplayNames = <String, String>{};
    final Map<String, int> historyEmotionCounts = <String, int>{
      'happy': 0,
      'sad': 0,
      'hype': 0,
      'romantic': 0,
    };

    for (final raw in history) {
      final record = _decodeHistoryAnalyticsEntry(raw);
      final title = (record['title'] ?? '').toString().trim();
      final artist = (record['artist'] ?? '').toString().trim();
      final genre = _normalizeGenre(record['genre']?.toString());
      final savedEmotion = record['emotion']?.toString();

      if (artist.isNotEmpty) {
        final key = _canonicalArtistKey(artist);
        if (key.isNotEmpty) {
          historyArtistCounts[key] = (historyArtistCounts[key] ?? 0) + 1;
          artistDisplayNames.putIfAbsent(key, () => artist);
        }
      }

      final emotion = _resolveSongEmotion(
        title: title,
        artist: artist,
        backendEmotion: savedEmotion,
        genre: genre,
      );
      historyEmotionCounts[emotion] =
          (historyEmotionCounts[emotion] ?? 0) + 1;
    }

    // Repair the historical "everything is happy" bug once. Existing history
    // is reclassified with the same rules now used for new recognitions.
    final int emotionSchema =
        prefs.getInt('analytics_emotion_schema_version') ?? 0;
    if (emotionSchema < 2) {
      for (final key in const ['happy', 'sad', 'hype', 'romantic']) {
        await prefs.setInt(
          'analytics_emotion_$key',
          historyEmotionCounts[key] ?? 0,
        );
      }
      await prefs.setInt('analytics_emotion_schema_version', 2);
    }

    // Merge history-derived counts into the permanent artist map using max()
    // rather than addition, so history and permanent analytics are not double
    // counted. This repairs older data while preserving sessions whose history
    // may already have been cleared.
    Map<String, dynamic> persistedArtists = <String, dynamic>{};
    final artistJson = prefs.getString('analytics_artist_counts');
    if (artistJson != null) {
      try {
        final decoded = jsonDecode(artistJson);
        if (decoded is Map) {
          persistedArtists = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {}
    }

    final Map<String, int> mergedCounts = <String, int>{};
    final Map<String, String> mergedDisplay = <String, String>{};

    persistedArtists.forEach((name, rawCount) {
      final sanitizedName = _sanitizeArtistName(name);
      if (sanitizedName.isEmpty) return;
      final key = _canonicalArtistKey(sanitizedName);
      if (key.isEmpty) return;
      final count = rawCount is num ? rawCount.toInt() : 0;
      mergedCounts[key] = max(mergedCounts[key] ?? 0, count).toInt();
      mergedDisplay.putIfAbsent(key, () => sanitizedName);
    });

    final bool artistWasManuallyCleared =
        prefs.getBool('analytics_artist_user_cleared_v1') ?? false;
    if (!artistWasManuallyCleared) {
      historyArtistCounts.forEach((key, count) {
        mergedCounts[key] = max(mergedCounts[key] ?? 0, count).toInt();
        mergedDisplay[key] =
            artistDisplayNames[key] ?? mergedDisplay[key] ?? key;
      });
    }

    final repairedArtistMap = <String, int>{};
    mergedCounts.forEach((key, count) {
      repairedArtistMap[mergedDisplay[key] ?? key] = count;
    });
    await prefs.setString(
      'analytics_artist_counts',
      jsonEncode(repairedArtistMap),
    );
  }

  List<Offset> _decodePinList(Iterable<String> encodedPins) {
    final offsets = <Offset>[];

    // Intentionally preserve duplicates. Multiple uses from the exact same
    // location should remain separate records and are allowed to paint on top
    // of one another on the world map.
    for (final raw in encodedPins) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is! Map) continue;
        final latValue = decoded['lat'];
        final lngValue = decoded['lng'];
        if (latValue is! num || lngValue is! num) continue;

        offsets.add(
          _latLngToMapOffset(latValue.toDouble(), lngValue.toDouble()),
        );
      } catch (_) {}
    }
    return offsets;
  }

  List<_AcousticUsagePin> _usagePinsFromLocations(
    Iterable<_AcousticLocationUsage> usages,
  ) {
    return usages
        .map(
          (usage) => _AcousticUsagePin(
            offset: _latLngToMapOffset(
              usage.latitude,
              usage.longitude,
            ),
            count: max(1, usage.count),
          ),
        )
        .toList();
  }

  Future<void> _refreshMapPinsOnly() async {
    final prefs = await SharedPreferences.getInstance();
    final activeSinging = prefs.getBool('is_currently_singing') ?? false;
    final activeRaw =
        prefs.getStringList('active_singing_locations') ?? <String>[];
    final usageLocations = await _loadAcousticLocationUsage(prefs);

    final activeOffsets = _decodePinList(activeRaw);
    final memoryOffsets = _usagePinsFromLocations(usageLocations);

    if (!mounted) return;
    if (_isCurrentlySinging == activeSinging &&
        listEquals(_livePinLocations, activeOffsets) &&
        listEquals(_memoryPinLocations, memoryOffsets)) {
      return;
    }

    setState(() {
      _isCurrentlySinging = activeSinging;
      _livePinLocations = activeOffsets;
      _memoryPinLocations = memoryOffsets;
    });
  }

  Future<void> _launchStreamingLink() async {
    // The title shown in the Vibe Match card and this URL are saved together
    // by _handleBiWeeklyPlaylistRotation. Do not recalculate here: that could
    // make a saved title open a different, newly-selected playlist.
    final targetUrl = _streamingUrl.trim();
    if (targetUrl.isEmpty) return;

    // Spotify universal links normally open the app, but use the native
    // spotify:playlist deep link first when Spotify is installed so the user
    // lands directly on the exact playlist rather than a search-results page.
    if (_preferredApp != 'apple_music') {
      try {
        final webUri = Uri.parse(targetUrl);
        final segments = webUri.pathSegments;
        final playlistIndex = segments.indexOf('playlist');
        if (playlistIndex >= 0 && playlistIndex + 1 < segments.length) {
          final playlistId = segments[playlistIndex + 1].trim();
          if (playlistId.isNotEmpty) {
            final nativeUri = Uri.parse('spotify:playlist:$playlistId');
            if (await canLaunchUrl(nativeUri)) {
              await launchUrl(
                nativeUri,
                mode: LaunchMode.externalApplication,
              );
              return;
            }
          }
        }
      } catch (_) {}
    }

    final uri = Uri.parse(targetUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _computeAnalytics({bool allowGenreBackfill = true}) async {
    final prefs = await SharedPreferences.getInstance();

    await _repairArtistAndEmotionAnalytics(prefs);

    _preferredApp = prefs.getString('preferred_music_app') ?? 'spotify';

    final bool activeSinging =
        prefs.getBool('is_currently_singing') ?? false;
    final activeRaw =
        prefs.getStringList('active_singing_locations') ?? <String>[];
    final usageLocations = await _loadAcousticLocationUsage(prefs);

    final calculatedLiveOffsets = _decodePinList(activeRaw);
    final calculatedMemoryOffsets =
        _usagePinsFromLocations(usageLocations);

    final Map<String, int> emotionMap = <String, int>{
      'happy': prefs.getInt('analytics_emotion_happy') ?? 0,
      'sad': prefs.getInt('analytics_emotion_sad') ?? 0,
      'hype': prefs.getInt('analytics_emotion_hype') ?? 0,
      'romantic': prefs.getInt('analytics_emotion_romantic') ?? 0,
    };

    final Map<String, int> artistMap = <String, int>{};
    final String? artistJson = prefs.getString('analytics_artist_counts');
    if (artistJson != null) {
      try {
        final decoded = jsonDecode(artistJson);
        if (decoded is Map) {
          decoded.forEach((key, value) {
            if (value is num && value.toInt() > 0) {
              artistMap[key.toString()] = value.toInt();
            }
          });
        }
      } catch (_) {}
    }

    final Map<String, int> rawGenreMap = <String, int>{};
    final String? genreJson = prefs.getString('analytics_genre_counts');
    if (genreJson != null) {
      try {
        final decoded = jsonDecode(genreJson);
        if (decoded is Map) {
          decoded.forEach((key, value) {
            if (value is! num || value.toInt() <= 0) return;
            final genre = _normalizeGenre(key.toString());
            if (genre.isEmpty) return;
            rawGenreMap[genre] =
                (rawGenreMap[genre] ?? 0) + value.toInt();
          });
        }
      } catch (_) {}
    }

    final sortedRawGenres = rawGenreMap.entries.toList()
      ..sort((a, b) {
        final countCompare = b.value.compareTo(a.value);
        return countCompare != 0
            ? countCompare
            : a.key.compareTo(b.key);
      });

    final Map<String, int> top4GenreCounts = <String, int>{
      for (final entry in sortedRawGenres.take(4)) entry.key: entry.value,
    };

    final sortedArtists = artistMap.entries.toList()
      ..sort((a, b) {
        final countCompare = b.value.compareTo(a.value);
        return countCompare != 0
            ? countCompare
            : a.key.toLowerCase().compareTo(b.key.toLowerCase());
      });
    final topArtistsList =
        sortedArtists.take(3).map((entry) => entry.key).toList();

    String calculatedMajority = 'fallback';
    final positiveEmotions = emotionMap.entries
        .where((entry) => entry.value > 0)
        .toList();
    if (positiveEmotions.isNotEmpty) {
      positiveEmotions.sort((a, b) => b.value.compareTo(a.value));
      calculatedMajority = positiveEmotions.first.key;
      if (positiveEmotions.length > 1 &&
          positiveEmotions[0].value == positiveEmotions[1].value) {
        calculatedMajority = 'fallback';
      }
    }

    final rawSessionDates =
        prefs.getStringList('analytics_session_dates') ?? <String>[];
    final sessionDates = rawSessionDates
        .map(DateTime.tryParse)
        .whereType<DateTime>()
        .toList();
    final calculatedStreak = _calculateStreak(sessionDates);

    if (!mounted) return;
    setState(() {
      _singingStreak = calculatedStreak;
      _topArtists = topArtistsList;
      _emotionCounts = emotionMap;
      _genreCounts = top4GenreCounts;
      _isCurrentlySinging = activeSinging;
      _livePinLocations = calculatedLiveOffsets;
      _memoryPinLocations = calculatedMemoryOffsets;
      _majorityEmotion = calculatedMajority;
    });

    final bool playlistWasManuallyCleared =
        prefs.getBool('analytics_playlist_user_cleared_v1') ?? false;
    if (playlistWasManuallyCleared) {
      if (mounted) {
        setState(() {
          _curatedPlaylistTitle = t('none');
          _streamingUrl = '';
          _countdownText = t('cleared');
        });
      }
    } else {
      await _handleBiWeeklyPlaylistRotation(prefs);
    }

    // Older history entries did not save genre. Backfill a limited number in
    // the background once, then refresh this page. New songs already arrive
    // with real backend/catalog genre and do not need this path.
    if (allowGenreBackfill && !_genreBackfillStarted) {
      _genreBackfillStarted = true;
      unawaited(_backfillLegacyHistoryGenres());
    }
  }

  Future<void> _backfillLegacyHistoryGenres() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('analytics_genre_user_cleared_v1') ?? false) return;
    if (prefs.getBool('analytics_genre_backfill_v2') ?? false) return;

    final history = prefs.getStringList('song_history') ?? <String>[];
    if (history.isEmpty) {
      await prefs.setBool('analytics_genre_backfill_v2', true);
      return;
    }

    final updatedHistory = List<String>.from(history);
    final targets = <Map<String, dynamic>>[];

    for (int i = 0; i < history.length && targets.length < 40; i++) {
      final record = _decodeHistoryAnalyticsEntry(history[i]);
      final existingGenre = _normalizeGenre(record['genre']?.toString());
      if (existingGenre.isNotEmpty) continue;

      final title = (record['title'] ?? '').toString().trim();
      final artist = (record['artist'] ?? '').toString().trim();
      if (title.isEmpty) continue;

      targets.add({
        'index': i,
        'record': record,
        'title': title,
        'artist': artist,
      });
    }

    const int batchSize = 4;
    for (int offset = 0; offset < targets.length; offset += batchSize) {
      final batch = targets.skip(offset).take(batchSize).toList();
      final metadata = await Future.wait(
        batch.map(
          (target) => fetchSongMetadataForSong(
            target['title'].toString(),
            target['artist'].toString(),
          ),
        ),
      );

      for (int j = 0; j < batch.length; j++) {
        final target = batch[j];
        final record =
            Map<String, dynamic>.from(target['record'] as Map);
        final genre = _normalizeGenre(metadata[j].genre);
        if (genre.isNotEmpty) {
          record['genre'] = genre;
        }
        final savedEmotion = _normalizeEmotion(record['emotion']?.toString());
        if (savedEmotion.isEmpty) {
          record['emotion'] = _resolveSongEmotion(
            title: target['title'].toString(),
            artist: target['artist'].toString(),
            genre: genre,
          );
        }
        updatedHistory[target['index'] as int] = jsonEncode(record);
      }
    }

    if (targets.isNotEmpty) {
      await prefs.setStringList('song_history', updatedHistory);
    }

    // Build genre counts from all history records that now have a known genre.
    final historyGenreCounts = <String, int>{};
    for (final raw in updatedHistory) {
      final record = _decodeHistoryAnalyticsEntry(raw);
      final genre = _normalizeGenre(record['genre']?.toString());
      if (genre.isEmpty) continue;
      historyGenreCounts[genre] = (historyGenreCounts[genre] ?? 0) + 1;
    }

    // Preserve permanent specific-genre counts from sessions whose history was
    // cleared, while taking the higher current-history count for each genre.
    final merged = <String, int>{};
    final existingJson = prefs.getString('analytics_genre_counts');
    if (existingJson != null) {
      try {
        final decoded = jsonDecode(existingJson);
        if (decoded is Map) {
          decoded.forEach((key, value) {
            final genre = _normalizeGenre(key.toString());
            if (genre.isNotEmpty && value is num && value.toInt() > 0) {
              merged[genre] = value.toInt();
            }
          });
        }
      } catch (_) {}
    }

    historyGenreCounts.forEach((genre, count) {
      merged[genre] = max(merged[genre] ?? 0, count).toInt();
    });

    await prefs.setString('analytics_genre_counts', jsonEncode(merged));
    await prefs.setBool('analytics_genre_backfill_v2', true);

    if (mounted) {
      await _computeAnalytics(allowGenreBackfill: false);
    }
  }

  String _compactPlaylistTitle(String rawTitle) {
    var title = rawTitle
        .replaceAll(' Essentials Mix', ' Mix')
        .replaceAll(' Essentials', '')
        .replaceAll('Best of ', '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (title.length <= 24) return title;

    if (title.toLowerCase().endsWith(' mix')) {
      final base = title.substring(0, title.length - 4).trim();
      final shortened = base.length > 17 ? '${base.substring(0, 17).trim()}…' : base;
      return '$shortened Mix';
    }
    return '${title.substring(0, 23).trim()}…';
  }

  Future<Map<String, String>?> _fetchAppleMusicPersonalRecommendation() async {
    if (kIsWeb || !Platform.isIOS) return null;

    try {
      final dynamic rawResult =
          await _recztAppleMusicChannel.invokeMethod<dynamic>(
        'getPersonalRecommendation',
      );

      if (rawResult is! Map) return null;
      final result = Map<String, dynamic>.from(rawResult);
      if (result['success'] != true) return null;

      final title = result['title']?.toString().trim() ?? '';
      final url = result['url']?.toString().trim() ?? '';
      final reason = result['reason']?.toString().trim() ?? '';

      if (title.isEmpty || url.isEmpty) return null;

      return <String, String>{
        'title': title,
        'url': url,
        'reason': reason,
      };
    } on MissingPluginException catch (e) {
      debugPrint('Apple Music recommendation bridge is unavailable: $e');
    } on PlatformException catch (e) {
      debugPrint(
        'Apple Music recommendations failed (${e.code}): ${e.message}',
      );
    } catch (e) {
      debugPrint('Apple Music recommendations failed: $e');
    }

    return null;
  }

  Future<void> _handleBiWeeklyPlaylistRotation(SharedPreferences prefs) async {
    const int fourteenDaysInMs = 14 * 24 * 60 * 60 * 1000;
    final int now = DateTime.now().millisecondsSinceEpoch;

    int? lastGeneratedTime = prefs.getInt('playlist_timestamp');

    final freshPlaylistData = _curatePlaylistFromProfile();
    final String profileSignature =
        freshPlaylistData['profile_signature'] ?? 'fallback|';

    String? savedSignature =
        prefs.getString('saved_curated_playlist_profile');
    String? savedSpotifyTitle =
        prefs.getString('saved_curated_playlist_spotify_title');
    String? savedAppleTitle =
        prefs.getString('saved_curated_playlist_apple_title');
    String? savedSpotifyUrl =
        prefs.getString('saved_curated_playlist_spotify_url');
    String? savedAppleUrl =
        prefs.getString('saved_curated_playlist_apple_url');

    bool savedApplePersonalized =
        prefs.getBool('saved_curated_playlist_apple_personalized') ?? false;
    int? appleRecommendationTimestamp =
        prefs.getInt('saved_curated_playlist_apple_timestamp');

    final bool missingSpotify =
        savedSpotifyTitle == null || savedSpotifyUrl == null;
    final bool missingApple =
        savedAppleTitle == null || savedAppleUrl == null;
    final bool profileChanged = savedSignature != profileSignature;
    final bool rotationExpired = lastGeneratedTime == null ||
        now - lastGeneratedTime > fourteenDaysInMs;

    // Spotify keeps Reczt's existing profile-driven Vibe Match behavior.
    if (missingSpotify || profileChanged || rotationExpired) {
      savedSpotifyTitle = _compactPlaylistTitle(
        freshPlaylistData['spotify_title'] ?? 'Happy Hits!',
      );
      savedSpotifyUrl = freshPlaylistData['spotify_url'] ?? '';
    }

    // Apple Music can use MusicKit's personal recommendations when authorized.
    // Those recommendations are based on the user's Apple Music library and
    // listening history. If MusicKit cannot return one, Reczt falls back to the
    // same emotion/genre profile-driven Apple Music playlist it used before.
    final bool appleRecommendationExpired =
        appleRecommendationTimestamp == null ||
        now - appleRecommendationTimestamp > fourteenDaysInMs;

    if (_preferredApp == 'apple_music' &&
        (missingApple || appleRecommendationExpired)) {
      final personalRecommendation =
          await _fetchAppleMusicPersonalRecommendation();

      if (personalRecommendation != null) {
        savedAppleTitle = _compactPlaylistTitle(
          personalRecommendation['title'] ?? 'Apple Music',
        );
        savedAppleUrl = personalRecommendation['url'] ?? '';
        savedApplePersonalized = true;
      } else {
        savedAppleTitle = _compactPlaylistTitle(
          freshPlaylistData['apple_title'] ?? 'Feeling Happy',
        );
        savedAppleUrl = freshPlaylistData['apple_url'] ?? '';
        savedApplePersonalized = false;
      }

      appleRecommendationTimestamp = now;
      await prefs.setInt(
        'saved_curated_playlist_apple_timestamp',
        appleRecommendationTimestamp,
      );
      await prefs.setBool(
        'saved_curated_playlist_apple_personalized',
        savedApplePersonalized,
      );
    } else if (missingApple ||
        (!savedApplePersonalized && profileChanged)) {
      // Keep a profile-driven fallback current even before Apple Music access
      // is granted. A personalized Apple recommendation is never overwritten
      // merely because the Reczt singing profile changes.
      savedAppleTitle = _compactPlaylistTitle(
        freshPlaylistData['apple_title'] ?? 'Feeling Happy',
      );
      savedAppleUrl = freshPlaylistData['apple_url'] ?? '';
      savedApplePersonalized = false;
      await prefs.setBool(
        'saved_curated_playlist_apple_personalized',
        false,
      );
    }

    savedSignature = profileSignature;

    if (lastGeneratedTime == null || profileChanged || rotationExpired) {
      lastGeneratedTime = now;
      await prefs.setInt('playlist_timestamp', now);
    }

    await prefs.setString(
      'saved_curated_playlist_profile',
      savedSignature,
    );
    await prefs.setString(
      'saved_curated_playlist_spotify_title',
      savedSpotifyTitle ?? '',
    );
    await prefs.setString(
      'saved_curated_playlist_apple_title',
      savedAppleTitle ?? '',
    );
    await prefs.setString(
      'saved_curated_playlist_spotify_url',
      savedSpotifyUrl ?? '',
    );
    await prefs.setString(
      'saved_curated_playlist_apple_url',
      savedAppleUrl ?? '',
    );

    // Keep the legacy key populated for users upgrading/downgrading builds.
    await prefs.setString(
      'saved_curated_playlist',
      _preferredApp == 'apple_music'
          ? (savedAppleTitle ?? '')
          : (savedSpotifyTitle ?? ''),
    );

    final String selectedTitle = _compactPlaylistTitle(
      _preferredApp == 'apple_music'
          ? (savedAppleTitle ?? 'Feeling Happy')
          : (savedSpotifyTitle ?? 'Happy Hits!'),
    );
    final String selectedUrl = _preferredApp == 'apple_music'
        ? (savedAppleUrl ?? '')
        : (savedSpotifyUrl ?? '');

    final int safeLastGeneratedTime = lastGeneratedTime ?? now;
    final int selectedTimestamp = _preferredApp == 'apple_music'
        ? (appleRecommendationTimestamp ?? safeLastGeneratedTime)
        : safeLastGeneratedTime;

    final int timeLeft = max(
      0,
      fourteenDaysInMs - (now - selectedTimestamp),
    ).toInt();
    final int daysLeft = timeLeft ~/ (24 * 60 * 60 * 1000);
    final int hoursLeft =
        (timeLeft % (24 * 60 * 60 * 1000)) ~/ (60 * 60 * 1000);

    if (!mounted) return;
    setState(() {
      _curatedPlaylistTitle = selectedTitle;
      _streamingUrl = selectedUrl;
      _countdownText = daysLeft > 0
          ? "${t('next_drop')}: \n ${daysLeft}d ${hoursLeft}h"
          : t('refreshing_soon');
    });
  }

  int _calculateStreak(List<DateTime> dates) {
    if (dates.isEmpty) return 0;

    List<DateTime> normalizedDates = dates
        .map((d) => DateTime(d.year, d.month, d.day))
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));

    DateTime today = DateTime.now();
    DateTime normalizedToday = DateTime(today.year, today.month, today.day);

    if (normalizedToday.difference(normalizedDates.first).inDays > 1) return 0;

    int streak = 0;
    DateTime expectedDate = normalizedDates.first;

    for (var date in normalizedDates) {
      if (date == expectedDate) {
        streak++;
        expectedDate = expectedDate.subtract(const Duration(days: 1));
      } else if (date.isBefore(expectedDate)) {
        break;
      }
    }
    return streak;
  }

  String _dominantGenreForPlaylist() {
    if (_genreCounts.isEmpty) return '';
    final entries = _genreCounts.entries.toList()
      ..sort((a, b) {
        final countCompare = b.value.compareTo(a.value);
        return countCompare != 0
            ? countCompare
            : a.key.compareTo(b.key);
      });
    return _normalizeGenre(entries.first.key);
  }

  /// Selects a real, direct playlist from the user's cumulative singing
  /// profile. The dominant emotion supplies the vibe while the dominant genre
  /// supplies musical style. Every returned URL points to an actual playlist,
  /// never to a search-results page.
  Map<String, String> _curatePlaylistFromProfile() {
    final normalizedEmotion = _normalizeEmotion(_majorityEmotion);
    final emotion = normalizedEmotion.isEmpty ? 'fallback' : normalizedEmotion;
    final genre = _dominantGenreForPlaylist();

    Map<String, String> recommendation({
      required String spotifyTitle,
      required String spotifyUrl,
      required String appleTitle,
      required String appleUrl,
    }) {
      return {
        'spotify_title': spotifyTitle,
        'spotify_url': spotifyUrl,
        'apple_title': appleTitle,
        'apple_url': appleUrl,
        'profile_signature': '$emotion|$genre',
      };
    }

    final bool isAlternative =
        genre == 'alternative' || genre == 'indie';
    final bool isDance =
        genre == 'dance' || genre == 'electronic';
    final bool isHipHop = genre == 'hip-hop/rap';
    final bool isRnB = genre == 'r&b/soul';
    final bool isRock = genre == 'rock' || genre == 'metal';

    // Strong emotion + genre combinations come first so the recommendation
    // reacts to both dimensions rather than simply choosing a generic mood.
    if (emotion == 'sad' && isAlternative) {
      return recommendation(
        spotifyTitle: 'Sad Songs',
        spotifyUrl:
            'https://open.spotify.com/playlist/37i9dQZF1DX7qK8ma5wgG1',
        appleTitle: 'Feeling Blue: Alternative',
        appleUrl:
            'https://music.apple.com/us/playlist/feeling-blue-alternative/pl.d3eb403f30e34f2a91095711211e2d14',
      );
    }

    if (emotion == 'romantic') {
      if (isRnB) {
        return recommendation(
          spotifyTitle: 'RNB X',
          spotifyUrl:
              'https://open.spotify.com/playlist/37i9dQZF1DX4SBhb3fqCJd',
          appleTitle: 'R&B Now',
          appleUrl:
              'https://music.apple.com/us/playlist/r-b-now/pl.b7ae3e0a28e84c5c96c4284b6a6c70af',
        );
      }
      return recommendation(
        spotifyTitle: 'Love Pop',
        spotifyUrl:
            'https://open.spotify.com/playlist/37i9dQZF1DX50QitC6Oqtn',
        appleTitle: 'Pure Romance',
        appleUrl:
            'https://music.apple.com/us/playlist/pure-romance/pl.2b0180f7fe5846348dda2dd60746cc48',
      );
    }

    if (emotion == 'hype') {
      if (isHipHop) {
        return recommendation(
          spotifyTitle: 'RapCaviar',
          spotifyUrl:
              'https://open.spotify.com/playlist/37i9dQZF1DX0XUsuxWHRQd',
          appleTitle: 'Rap Life',
          appleUrl:
              'https://music.apple.com/us/playlist/rap-life/pl.abe8ba42278f4ef490e3a9fc5ec8e8c5',
        );
      }
      if (isDance) {
        return recommendation(
          spotifyTitle: 'mint',
          spotifyUrl:
              'https://open.spotify.com/playlist/37i9dQZF1DX4dyzvuaRJ0n',
          appleTitle: 'danceXL',
          appleUrl:
              'https://music.apple.com/us/playlist/dancexl/pl.6bf4415b83ce4f3789614ac4c3675740',
        );
      }
      return recommendation(
        spotifyTitle: 'Beast Mode',
        spotifyUrl:
            'https://open.spotify.com/playlist/37i9dQZF1DX76Wlfdnj7AP',
        appleTitle: 'Pure Workout',
        appleUrl:
            'https://music.apple.com/us/playlist/pure-workout/pl.ad0ee1557e3e4feba314fd70f7982766',
      );
    }

    if (emotion == 'sad') {
      return recommendation(
        spotifyTitle: 'Sad Songs',
        spotifyUrl:
            'https://open.spotify.com/playlist/37i9dQZF1DX7qK8ma5wgG1',
        appleTitle: 'Feeling Blue',
        appleUrl:
            'https://music.apple.com/us/playlist/feeling-blue/pl.0f458c8569ef4a39a95f6ad4d6c54ba0',
      );
    }

    // When the emotional profile is happy/balanced (or tied), let the actual
    // most-sung genre drive the choice. This is what makes genre meaningful in
    // the Vibe Match recommendation rather than merely decorative analytics.
    if (isAlternative) {
      return recommendation(
        spotifyTitle: 'ALT NOW',
        spotifyUrl:
            'https://open.spotify.com/playlist/37i9dQZF1DWVqJMsgEN0F4',
        appleTitle: 'ALT CTRL',
        appleUrl:
            'https://music.apple.com/us/playlist/alt-ctrl/pl.0b593f1142b84a50a2c1e7088b3fb683',
      );
    }
    if (isHipHop) {
      return recommendation(
        spotifyTitle: 'RapCaviar',
        spotifyUrl:
            'https://open.spotify.com/playlist/37i9dQZF1DX0XUsuxWHRQd',
        appleTitle: 'Rap Life',
        appleUrl:
            'https://music.apple.com/us/playlist/rap-life/pl.abe8ba42278f4ef490e3a9fc5ec8e8c5',
      );
    }
    if (isRnB) {
      return recommendation(
        spotifyTitle: 'RNB X',
        spotifyUrl:
            'https://open.spotify.com/playlist/37i9dQZF1DX4SBhb3fqCJd',
        appleTitle: 'R&B Now',
        appleUrl:
            'https://music.apple.com/us/playlist/r-b-now/pl.b7ae3e0a28e84c5c96c4284b6a6c70af',
      );
    }
    if (genre == 'country') {
      return recommendation(
        spotifyTitle: 'Hot Country',
        spotifyUrl:
            'https://open.spotify.com/playlist/37i9dQZF1DX1lVhptIYRda',
        appleTitle: "Today's Country",
        appleUrl:
            'https://music.apple.com/us/playlist/todays-country/pl.87bb5b36a9bd49db8c975607452bfa2b',
      );
    }
    if (isDance) {
      return recommendation(
        spotifyTitle: 'mint',
        spotifyUrl:
            'https://open.spotify.com/playlist/37i9dQZF1DX4dyzvuaRJ0n',
        appleTitle: 'danceXL',
        appleUrl:
            'https://music.apple.com/us/playlist/dancexl/pl.6bf4415b83ce4f3789614ac4c3675740',
      );
    }
    if (isRock) {
      return recommendation(
        spotifyTitle: 'Rock Classics',
        spotifyUrl:
            'https://open.spotify.com/playlist/37i9dQZF1DWXRqgorJj26U',
        appleTitle: 'Rock Classics',
        appleUrl:
            'https://music.apple.com/us/playlist/rock-classics/pl.ae12fec18a8b471788ee5956ac67b95a',
      );
    }

    // Pop, singer/songwriter, folk, jazz, classical, Latin and any specific
    // catalog genre that does not yet have a dedicated direct-playlist mapping
    // fall back to the user's dominant emotional vibe rather than an "Other"
    // genre bucket.
    if (emotion == 'happy') {
      return recommendation(
        spotifyTitle: 'Happy Hits!',
        spotifyUrl:
            'https://open.spotify.com/playlist/37i9dQZF1DXdPec7aLTmlC',
        appleTitle: 'Feeling Happy',
        appleUrl:
            'https://music.apple.com/us/playlist/feeling-happy/pl.0d4aee5424c74d29ad15252eeb43d3b1',
      );
    }

    return recommendation(
      spotifyTitle: 'Happy Hits!',
      spotifyUrl:
          'https://open.spotify.com/playlist/37i9dQZF1DXdPec7aLTmlC',
      appleTitle: 'Feeling Happy',
      appleUrl:
          'https://music.apple.com/us/playlist/feeling-happy/pl.0d4aee5424c74d29ad15252eeb43d3b1',
    );
  }


  Widget _buildAcousticMapPin(
    Offset pinOffset, {
    bool live = false,
    int count = 1,
    double size = 26,
  }) {
    final safeCount = max(1, count);
    final usageSize = live
        ? size
        : min(34.0, 20.0 + (sqrt(safeCount.toDouble()) * 2.5));
    final usageOpacity = live
        ? 1.0
        : min(0.96, 0.58 + (log(safeCount + 1) * 0.10));
    return Align(
      alignment: FractionalOffset(pinOffset.dx, pinOffset.dy),
      child: live
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black38,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    t('live_pin_label'),
                    style: const TextStyle(
                      fontSize: 8,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Icon(Icons.location_on, color: Colors.redAccent, size: size),
              ],
            )
          : Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  Icons.location_on,
                  color: Colors.redAccent.withValues(alpha: usageOpacity),
                  size: usageSize,
                ),
                if (safeCount > 1)
                  Positioned(
                    right: -7,
                    top: -6,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 18),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white, width: 1),
                      ),
                      child: Text(
                        safeCount > 99 ? '99+' : '$safeCount',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

void _showShareCardModal(BuildContext context) {
  final themeColor = Theme.of(context).colorScheme.primary;
  final isDarkMode = Theme.of(context).brightness == Brightness.dark;
  final GlobalKey previewCardKey = GlobalKey(); // Key to capture widget as image

  // Updated color mapping: Red = happy, Blue = sad, Yellow = hype, Pink = romantic
  const emotionColors = <String, Color>{
    'happy': Colors.red,
    'sad': Colors.blue,
    'hype': Colors.amber, // Using amber/yellow for hype
    'romantic': Colors.purpleAccent,
  };

  // Dynamic fallbacks based on class state
  final currentArtist = _topArtists.isNotEmpty ? _topArtists.first : t('none');

  // Calculate total emotion counts & active keys
  final double totalCounts = _emotionCounts.keys.fold(
    0.0,
    (sum, key) => sum + (_emotionCounts[key] ?? 0).toDouble(),
  );
  final activeKeys = _emotionCounts.keys.where((key) => (_emotionCounts[key] ?? 0) > 0).toList();
  final int modalMaxGenreCount = _genreCounts.values.isEmpty
      ? 1
      : _genreCounts.values
          .reduce((a, b) => a > b ? a : b)
          .clamp(1, 1 << 30)
          .toInt();
  double getEmotionPct(String key) {
    if (totalCounts == 0) return 0;
    return ((_emotionCounts[key] ?? 0).toDouble() / totalCounts) * 100;
  }

  // Dynamic pie chart section logic
  List<PieChartSectionData> modalEmotionSections;
  if (totalCounts == 0) {
    modalEmotionSections = [
      PieChartSectionData(color: Colors.white24, value: 1, title: '', radius: 16)
    ];
  } else if (activeKeys.length == 1) {
    modalEmotionSections = [
      PieChartSectionData(
        color: emotionColors[activeKeys.first] ?? themeColor,
        value: totalCounts,
        title: '',
        radius: 16,
      )
    ];
  } else {
    modalEmotionSections = activeKeys.map((key) {
      return PieChartSectionData(
        color: emotionColors[key] ?? themeColor,
        value: (_emotionCounts[key] ?? 0).toDouble(),
        title: '',
        radius: 16,
      );
    }).toList();
  }

  // Share the analytics preview as a tappable Reczt rich-link card.
  // The captured PNG is used only as Link Presentation artwork on iOS; it is
  // no longer sent to the recipient as a standalone photo attachment.
  Future<void> captureAndShare() async {
    final previewPath = await _captureRichSharePreview(
      previewCardKey,
      'reczt_analytics_link_preview.png',
    );

    await shareRecztInteractiveCard(
      context: context,
      title: t('analytics_title'),
      message: t('analytics_share_text'),
      previewImagePath: previewPath,
    );
  }

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (modalContext) {
      return Container(
        padding: const EdgeInsets.all(24.0),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Modal Handle Bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // GRAPHICS CARD PREVIEW
              RepaintBoundary(
                key: previewCardKey,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        themeColor.withValues(alpha: 0.85),
                        const Color(0xFF121212),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: themeColor.withValues(alpha: 0.5), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: themeColor.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Title Header
                      Text(
                        t('analytics_title'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Donut Chart & Emotion Breakdown
                      Row(
                        children: [
                          Expanded(
                            flex: 5,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: activeKeys.map((rawKey) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: emotionColors[rawKey] ?? themeColor,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        "${getEmotionPct(rawKey).toStringAsFixed(0)}% ${t(rawKey)}",
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.white70,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),

                          Expanded(
                            flex: 4,
                            child: SizedBox(
                              height: 90,
                              child: PieChart(
                                PieChartData(
                                  sectionsSpace: activeKeys.length == 1 ? 0 : 2,
                                  centerSpaceRadius: 18,
                                  sections: modalEmotionSections,
                                ),
                                swapAnimationDuration: const Duration(milliseconds: 600),
                                swapAnimationCurve: Curves.easeInOutCubic,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(color: Colors.white24, height: 1),
                      const SizedBox(height: 16),

                      // Most Sung Genres Chart Section
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t('most_sung_genres'),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (_genreCounts.isEmpty)
                            Text(
                              t('none'),
                              style: const TextStyle(fontSize: 11, color: Colors.white54),
                            )
                          else
                            Column(
                              children: _genreCounts.entries.take(4).map((genre) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 3.0),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: Text(
                                          _genreLabel(genre.key),
                                          style: const TextStyle(fontSize: 11, color: Colors.white),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        flex: 7,
                                        child: LinearProgressIndicator(
                                          value: genre.value / modalMaxGenreCount,
                                          backgroundColor: Colors.white12,
                                          color: themeColor,
                                          minHeight: 6,
                                          borderRadius: BorderRadius.circular(3),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(color: Colors.white24, height: 1),
                      const SizedBox(height: 16),

                      // Acoustic Map Section
                                            // ACOUSTIC MAP WITH WORLD MAP IMAGE & PINS
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              t('acoustic_map').toUpperCase(),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: themeColor,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 140,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: Container(
                                      color: isDarkMode ? const Color(0xFF1E2638) : const Color(0xFFE8F0FE),
                                      child: Image.asset(
                                        'assets/world_map.png',
                                        fit: BoxFit.cover,
                                        color: isDarkMode ? Colors.white70 : themeColor.withValues(alpha: 0.75),
                                        colorBlendMode: BlendMode.modulate,
                                        errorBuilder: (context, error, stackTrace) => Container(
                                          color: isDarkMode ? Colors.grey.shade900 : Colors.blueGrey.shade100,
                                          child: Center(
                                            child: Icon(Icons.public, size: 60, color: themeColor.withValues(alpha: 0.4)),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  ..._memoryPinLocations.map(
                                    (usagePin) => _buildAcousticMapPin(
                                      usagePin.offset,
                                      count: usagePin.count,
                                      size: 24,
                                    ),
                                  ),
                                  if (_isCurrentlySinging &&
                                      _livePinLocations.isNotEmpty)
                                    ..._livePinLocations.map(
                                      (pinOffset) => _buildAcousticMapPin(
                                        pinOffset,
                                        live: true,
                                        size: 30,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Stats Row: Streak, Top Artist & Vibe Match Playlist
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Streak Metric
                          Column(
                            children: [
                              const Icon(Icons.local_fire_department, color: Colors.orange, size: 22),
                              const SizedBox(height: 2),
                              Text(
                                "$_singingStreak",
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                t('streak_title'),
                                style: const TextStyle(fontSize: 10, color: Colors.white60),
                              ),
                            ],
                          ),
                          Container(width: 1, height: 32, color: Colors.white24),
                          // Top Artist Metric
                          Column(
                            children: [
                              const Icon(Icons.star, color: Colors.amber, size: 22),
                              const SizedBox(height: 2),
                              Text(
                                currentArtist,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                t('top_artist'),
                                style: const TextStyle(fontSize: 10, color: Colors.white60),
                              ),
                            ],
                          ),
                          Container(width: 1, height: 32, color: Colors.white24),
                          // Vibe Match Playlist Metric
                          Column(
                            children: [
                              const Icon(Icons.queue_music, color: Colors.tealAccent, size: 22),
                              const SizedBox(height: 2),
                              SizedBox(
                                width: 90,
                                child: Text(
                                  _curatedPlaylistTitle,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              Text(
                                t('vibe_match_playlist'),
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 10, color: Colors.white60),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // App Badge Link
                      InkWell(
                        onTap: () async {
                          final uri = Uri.parse(reczAppStoreUrl);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          }
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white30, width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.open_in_new_rounded, size: 14, color: Colors.white70),
                              SizedBox(width: 6),
                              Text(
                                "Reczt",
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 0.8,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Active Share Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: themeColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () async {
                    await captureAndShare();
                  },
                  icon: const Icon(Icons.share, color: Colors.white),
                  label: Text(
                    t('share_card'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
  @override
  Widget build(BuildContext context) {
    final themeColor = Theme.of(context).colorScheme.primary;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Screen size dynamic height calculations for precise device responsiveness
    final screenSize = MediaQuery.of(context).size;
    final double topRowHeight = (screenSize.height * 0.16).clamp(120.0, 150.0);
    final double mapHeight = (screenSize.height * 0.26).clamp(180.0, 260.0);

    final sortedGenres = _genreCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    int maxGenreCount = sortedGenres.isNotEmpty ? sortedGenres.first.value : 1;
    if (maxGenreCount == 0) maxGenreCount = 1;

    int totalEmotions = _emotionCounts.values.fold(0, (sum, count) => sum + count);

    double getEmotionPct(String rawKey) {
      if (totalEmotions == 0) return 0;
      return ((_emotionCounts[rawKey] ?? 0) / totalEmotions) * 100;
    }

    final rawEmotionKeys = ['happy', 'sad', 'hype', 'romantic'];
    final Map<String, Color> emotionColors = {
      'happy': Colors.redAccent,
      'sad': Colors.blueAccent,
      'hype': Colors.orangeAccent,
      'romantic': Colors.purpleAccent,
    };

    final activeEmotionKeys = rawEmotionKeys.where((key) => (_emotionCounts[key] ?? 0) > 0).toList();

    List<PieChartSectionData> emotionSections;
    if (totalEmotions == 0) {
      // No data yet — show a single neutral placeholder ring.
      emotionSections = [
        PieChartSectionData(
          color: Colors.grey.withValues(alpha: 0.3),
          value: 1,
          title: '',
          radius: 18,
        ),
      ];
    } else if (activeEmotionKeys.length == 1) {
      // Exactly one emotion recorded so far — fill the whole ring with it.
      emotionSections = [
        PieChartSectionData(
          color: emotionColors[activeEmotionKeys.first],
          value: totalEmotions.toDouble(),
          title: '',
          radius: 18,
        ),
      ];
    } else {
      // Real proportional slices — only emotions that actually occurred,
      // sized by their true share of the total so the donut matches the
      // percentages shown in the legend.
      emotionSections = activeEmotionKeys.map((rawKey) {
        final count = (_emotionCounts[rawKey] ?? 0).toDouble();
        return PieChartSectionData(
          color: emotionColors[rawKey],
          value: count,
          title: '',
          radius: 18,
        );
      }).toList();
    }

    return Scaffold(
      appBar: AppBar(
  title: Text(
    t('analytics_title'),
    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: themeColor),
  ),
  centerTitle: true,
  actions: [
    IconButton(
      icon: const Icon(Icons.share),
      tooltip: t('quickshare_tooltip'),
      onPressed: () => _showShareCardModal(context),
    ),
  ],
),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              children: [
                // ROW 1: 3 EVENLY SPACED TOP CARDS (RESPONSIVE HEIGHT & AUTO-SCALED TEXT)
                SizedBox(
                  height: topRowHeight,
                  child: Row(
                    children: [
                      // Card 1: Streak
                      Expanded(
                        child: _buildClearableAnalyticsCard(
                          sectionKey: 'streak',
                          sectionLabel: t('streak_title'),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.local_fire_department, color: Colors.orange, size: 26),
                              const SizedBox(height: 4),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  "$_singingStreak",
                                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: themeColor),
                                ),
                              ),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  t('streak_title'),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Card 2: Top Artist
                      Expanded(
                        child: _buildClearableAnalyticsCard(
                          sectionKey: 'artist',
                          sectionLabel: t('top_artist'),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.star, color: Colors.amber, size: 26),
                              const SizedBox(height: 4),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  _topArtists.isNotEmpty ? _topArtists.first : t('none'),
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: themeColor),
                                ),
                              ),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  t('top_artist'),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Card 3: Recommended Vibes Playlist
                      Expanded(
                        child: _buildClearableAnalyticsCard(
                          sectionKey: 'playlist',
                          sectionLabel: t('vibe_match_playlist'),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  _countdownText.toUpperCase(),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: themeColor),
                                ),
                              ),
                              const SizedBox(height: 4),
                              InkWell(
                                onTap: _launchStreamingLink,
                                child: SizedBox(
                                  width: double.infinity,
                                  child: Text(
                                    _curatedPlaylistTitle,
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: themeColor,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  preferredPlatform,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ROW 2: FULL-WIDTH ACOUSTIC MAP (DYNAMICALLY PROPORTIONED HEIGHT)
                SizedBox(
                  height: mapHeight,
                  child: _buildClearableAnalyticsCard(
                    sectionKey: 'map',
                    sectionLabel: t('acoustic_map'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            t('acoustic_map').toUpperCase(),
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: themeColor),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: Container(
                                    color: isDarkMode ? const Color(0xFF1E2638) : const Color(0xFFE8F0FE),
                                    child: Image.asset(
                                      'assets/world_map.png',
                                      fit: BoxFit.cover,
                                      color: isDarkMode ? Colors.white70 : themeColor.withValues(alpha: 0.75),
                                      colorBlendMode: BlendMode.modulate,
                                      errorBuilder: (context, error, stackTrace) => Container(
                                        color: isDarkMode ? Colors.grey.shade900 : Colors.blueGrey.shade100,
                                        child: Center(
                                          child: Icon(Icons.public, size: 80, color: themeColor.withValues(alpha: 0.4)),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                ..._memoryPinLocations.map(
                                    (usagePin) => _buildAcousticMapPin(
                                      usagePin.offset,
                                      count: usagePin.count,
                                      size: 24,
                                    ),
                                  ),
                                  if (_isCurrentlySinging &&
                                      _livePinLocations.isNotEmpty)
                                    ..._livePinLocations.map(
                                      (pinOffset) => _buildAcousticMapPin(
                                        pinOffset,
                                        live: true,
                                        size: 30,
                                      ),
                                    ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // ROW 3: FULL-WIDTH MOST SUNG GENRES
                _buildClearableAnalyticsCard(
                  sectionKey: 'genres',
                  sectionLabel: t('most_sung_genres'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t('most_sung_genres').toUpperCase(),
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: themeColor),
                      ),
                      const SizedBox(height: 10),
                      if (sortedGenres.isEmpty)
                        Text(t('none'), style: const TextStyle(fontSize: 12, color: Colors.grey))
                      else ...[
                        for (int i = 0; i < 4; i++) ...[
                          if (i < sortedGenres.length) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _genreLabel(sortedGenres[i].key),
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  "${sortedGenres[i].value} ${t('songs')}",
                                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            LinearProgressIndicator(
                              value: sortedGenres[i].value / maxGenreCount,
                              color: _getBarColor(i, themeColor),
                              backgroundColor: Colors.grey.withValues(alpha: 0.15),
                              minHeight: 7,
                            ),
                            if (i < 3) const SizedBox(height: 8),
                          ],
                        ],
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ROW 4: FULL-WIDTH EMOTIONS DONUT CHART
                _buildClearableAnalyticsCard(
  sectionKey: 'emotions',
  sectionLabel: t('emotions'),
  child: Row(
    children: [
      // Legend Column
      Expanded(
        flex: 5,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: rawEmotionKeys.map((rawKey) {
            return _buildLegendRow(
              "${getEmotionPct(rawKey).toStringAsFixed(0)}% ${t(rawKey)}",
              emotionColors[rawKey]!,
            );
          }).toList(),
        ),
      ),

      // Pie Chart
      Expanded(
        flex: 4,
        child: SizedBox(
          height: 120,
          child: PieChart(
            PieChartData(
              // Remove section spacing if only 1 emotion is active so there are no seams
              sectionsSpace: activeEmotionKeys.length <= 1 ? 0 : 3,
              centerSpaceRadius: 24,
              sections: emotionSections,
            ),
            swapAnimationDuration: const Duration(milliseconds: 600),
            swapAnimationCurve: Curves.easeInOutCubic,
          ),
        ),
      ),
    ],
  ),
),
                const SizedBox(height: 20),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  onPressed: _showClearRecztDataDialog,
                  icon: const Icon(Icons.delete_forever_outlined, size: 18),
                  label: Text(
                    t('clear_reczt_data'),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(
                    left: 20,
                    right: 20,
                    bottom: 8,
                  ),
                  child: Text(
                    t('clear_reczt_data_desc'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: Colors.grey,
                      height: 1.25,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThemedCard({required Widget child}) {
    final themeColor = Theme.of(context).colorScheme.primary;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: themeColor.withValues(alpha: 0.55), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: themeColor.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(10),
      child: child,
    );
  }

  Widget _buildLegendRow(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        children: [
          Container(width: 12, height: 12, color: color),
          const SizedBox(width: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Color _getBarColor(int index, Color themePrimary) {
    switch (index) {
      case 0:
        return themePrimary;
      case 1:
        return Colors.pinkAccent;
      case 2:
        return Colors.orangeAccent;
      case 3:
        return Colors.tealAccent;
      default:
        return themePrimary;
    }
  }
}

int _rotateRight32(int value, int amount) {
  final v = value & 0xFFFFFFFF;
  return ((v >> amount) | (v << (32 - amount))) & 0xFFFFFFFF;
}

/// Small self-contained SHA-256 implementation used only to generate Spotify's
/// PKCE code challenge. Keeping it here avoids requiring another pubspec
/// dependency just for OAuth.
List<int> _sha256Digest(List<int> input) {
  const k = <int>[
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5,
    0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
    0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
    0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
    0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
    0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
    0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5,
    0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
    0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
  ];

  final bytes = List<int>.from(input)..add(0x80);
  while (bytes.length % 64 != 56) {
    bytes.add(0);
  }
  final bitLength = input.length * 8;
  for (int shift = 56; shift >= 0; shift -= 8) {
    bytes.add((bitLength >> shift) & 0xFF);
  }

  int h0 = 0x6a09e667;
  int h1 = 0xbb67ae85;
  int h2 = 0x3c6ef372;
  int h3 = 0xa54ff53a;
  int h4 = 0x510e527f;
  int h5 = 0x9b05688c;
  int h6 = 0x1f83d9ab;
  int h7 = 0x5be0cd19;

  for (int offset = 0; offset < bytes.length; offset += 64) {
    final w = List<int>.filled(64, 0);
    for (int i = 0; i < 16; i++) {
      final j = offset + i * 4;
      w[i] = ((bytes[j] << 24) |
              (bytes[j + 1] << 16) |
              (bytes[j + 2] << 8) |
              bytes[j + 3]) &
          0xFFFFFFFF;
    }
    for (int i = 16; i < 64; i++) {
      final s0 = _rotateRight32(w[i - 15], 7) ^
          _rotateRight32(w[i - 15], 18) ^
          (w[i - 15] >> 3);
      final s1 = _rotateRight32(w[i - 2], 17) ^
          _rotateRight32(w[i - 2], 19) ^
          (w[i - 2] >> 10);
      w[i] = (w[i - 16] + s0 + w[i - 7] + s1) & 0xFFFFFFFF;
    }

    int a = h0;
    int b = h1;
    int c = h2;
    int d = h3;
    int e = h4;
    int f = h5;
    int g = h6;
    int h = h7;

    for (int i = 0; i < 64; i++) {
      final s1 = _rotateRight32(e, 6) ^
          _rotateRight32(e, 11) ^
          _rotateRight32(e, 25);
      final ch = (e & f) ^ ((~e) & g);
      final temp1 = (h + s1 + ch + k[i] + w[i]) & 0xFFFFFFFF;
      final s0 = _rotateRight32(a, 2) ^
          _rotateRight32(a, 13) ^
          _rotateRight32(a, 22);
      final maj = (a & b) ^ (a & c) ^ (b & c);
      final temp2 = (s0 + maj) & 0xFFFFFFFF;

      h = g;
      g = f;
      f = e;
      e = (d + temp1) & 0xFFFFFFFF;
      d = c;
      c = b;
      b = a;
      a = (temp1 + temp2) & 0xFFFFFFFF;
    }

    h0 = (h0 + a) & 0xFFFFFFFF;
    h1 = (h1 + b) & 0xFFFFFFFF;
    h2 = (h2 + c) & 0xFFFFFFFF;
    h3 = (h3 + d) & 0xFFFFFFFF;
    h4 = (h4 + e) & 0xFFFFFFFF;
    h5 = (h5 + f) & 0xFFFFFFFF;
    h6 = (h6 + g) & 0xFFFFFFFF;
    h7 = (h7 + h) & 0xFFFFFFFF;
  }

  final output = <int>[];
  for (final word in [h0, h1, h2, h3, h4, h5, h6, h7]) {
    output
      ..add((word >> 24) & 0xFF)
      ..add((word >> 16) & 0xFF)
      ..add((word >> 8) & 0xFF)
      ..add(word & 0xFF);
  }
  return output;
}

String _randomPkceString(int length) {
  const chars =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
  final random = Random.secure();
  return List.generate(length, (_) => chars[random.nextInt(chars.length)]).join();
}

String _base64UrlWithoutPadding(List<int> bytes) =>
    base64Url.encode(bytes).replaceAll('=', '');

class SpotifyService {
  static const String clientId = 'b2a0f02419ce44b5a443785d92681273';
  static const String redirectUri = 'reczt://callback';
  static const String scopes =
      'playlist-modify-public playlist-modify-private';

  /// Spotify removed Implicit Grant support for mobile apps. Reczt now uses
  /// Authorization Code + PKCE, which needs no client secret inside the app.
  Future<String?> authenticate() async {
    final verifier = _randomPkceString(64);
    final challenge = _base64UrlWithoutPadding(
      _sha256Digest(utf8.encode(verifier)),
    );
    final state = _randomPkceString(32);

    final authUrl = Uri.https('accounts.spotify.com', '/authorize', {
      'client_id': clientId,
      'response_type': 'code',
      'redirect_uri': redirectUri,
      'scope': scopes,
      'code_challenge_method': 'S256',
      'code_challenge': challenge,
      'state': state,
      'show_dialog': 'true',
    });

    try {
      final result = await FlutterWebAuth2.authenticate(
        url: authUrl.toString(),
        callbackUrlScheme: 'reczt',
      );

      final parsedUri = Uri.parse(result);
      if (parsedUri.queryParameters['state'] != state) return null;
      if (parsedUri.queryParameters['error'] != null) return null;
      final code = parsedUri.queryParameters['code'];
      if (code == null || code.isEmpty) return null;

      final tokenResponse = await http.post(
        Uri.parse('https://accounts.spotify.com/api/token'),
        headers: const {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'client_id': clientId,
          'grant_type': 'authorization_code',
          'code': code,
          'redirect_uri': redirectUri,
          'code_verifier': verifier,
        },
      ).timeout(const Duration(seconds: 20));

      if (tokenResponse.statusCode != 200) return null;
      final data = jsonDecode(tokenResponse.body);
      return data['access_token']?.toString();
    } catch (e) {
      debugPrint('Spotify PKCE authorization failed: $e');
      return null;
    }
  }

  Future<String?> _searchTrackUri(
    String queryText,
    Map<String, String> headers,
  ) async {
    final query = Uri.encodeComponent(queryText);
    final searchRes = await http.get(
      Uri.parse(
        'https://api.spotify.com/v1/search?q=$query&type=track&limit=1',
      ),
      headers: headers,
    ).timeout(const Duration(seconds: 12));

    if (searchRes.statusCode == 200) {
      final decoded = jsonDecode(searchRes.body);
      final tracks = decoded is Map ? decoded['tracks'] : null;
      final items = tracks is Map ? tracks['items'] : null;
      if (items is List && items.isNotEmpty && items.first is Map) {
        return (items.first as Map)['uri']?.toString();
      }
    }
    return null;
  }

  /// Searches in small concurrent batches to stay responsive without sending
  /// a large burst of Spotify requests for a long Reczt history.
  Future<String?> createPlaylistFromHistory(
    String token,
    List<String> songQueries,
    String Function(String) t,
  ) async {
    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };

    try {
      final List<String> trackUris = [];
      const batchSize = 5;
      for (int i = 0; i < songQueries.length; i += batchSize) {
        final batch = songQueries.skip(i).take(batchSize);
        final results = await Future.wait(
          batch.map((query) => _searchTrackUri(query, headers)),
        );
        trackUris.addAll(results.whereType<String>());
      }

      if (trackUris.isEmpty) return null;

      final playlistRes = await http.post(
        Uri.parse('https://api.spotify.com/v1/me/playlists'),
        headers: headers,
        body: jsonEncode({
          'name': t('playlist_name'),
          'description': t('playlist_desc'),
          'public': true,
        }),
      ).timeout(const Duration(seconds: 15));

      if (playlistRes.statusCode != 201) return null;
      final decodedPlaylist = jsonDecode(playlistRes.body);
      final playlistId = decodedPlaylist is Map
          ? decodedPlaylist['id']?.toString()
          : null;
      if (playlistId == null || playlistId.isEmpty) return null;

      for (int i = 0; i < trackUris.length; i += 100) {
        final uris = trackUris.skip(i).take(100).toList();
        final addRes = await http.post(
          Uri.parse(
            'https://api.spotify.com/v1/playlists/$playlistId/items',
          ),
          headers: headers,
          body: jsonEncode({'uris': uris}),
        ).timeout(const Duration(seconds: 15));
        if (addRes.statusCode != 201 && addRes.statusCode != 200) {
          return null;
        }
      }

      // Returning the ID lets the History page immediately deep-link the user
      // to the playlist that Reczt just created.
      return playlistId;
    } catch (e) {
      debugPrint('Spotify playlist creation failed: $e');
      return null;
    }
  }
}


// LOCALIZED SEARCH HISTORY & PLAYBACK PAGE
// ----------------------------------------------------
class HistoryPage extends StatefulWidget {
  final String lang;
  const HistoryPage({super.key, required this.lang});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<String> _history = [];
  List<String> _pendingQueue = [];
  final Set<String> _selectedItems = {};

  late final AudioPlayer _clipPlayer;
  String? _currentlyPlayingPath;
  bool _isPlayingClip = false;

  String t(String key) {
    return localizedStrings[widget.lang]?[key] ??
        localizedStrings['en']?[key] ??
        key;
  }

  @override
  void initState() {
    super.initState();
    _clipPlayer = AudioPlayer();

    _clipPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlayingClip = false;
          _currentlyPlayingPath = null;
        });
      }
    });

    _loadHistoryAndQueue();
  }

  @override
  void dispose() {
    _clipPlayer.stop();
    _clipPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadHistoryAndQueue() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    setState(() {
      _history = prefs.getStringList('song_history') ?? [];
      _pendingQueue = prefs.getStringList('pending_offline_songs') ?? [];
      _selectedItems.clear();
      _selectedItems.addAll(_history);
    });
  }

  Future<void> _clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final audioFiles = _history
        .map(_parseAudioPath)
        .whereType<String>()
        .where((path) => path.isNotEmpty)
        .toList();

    await _clipPlayer.stop();
    await prefs.remove('song_history');

    if (!kIsWeb) {
      for (final path in audioFiles) {
        try {
          final file = File(path);
          if (await file.exists()) await file.delete();
        } catch (e) {
          debugPrint('Could not delete saved singing clip: $e');
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _history.clear();
      _selectedItems.clear();
      _isPlayingClip = false;
      _currentlyPlayingPath = null;
    });
  }

  Future<void> _deleteHistoryItem(int index) async {
    if (index < 0 || index >= _history.length) return;
    final prefs = await SharedPreferences.getInstance();
    final itemToRemove = _history[index];
    final audioPath = _parseAudioPath(itemToRemove);

    if (_currentlyPlayingPath == audioPath) {
      await _clipPlayer.stop();
    }

    if (!mounted) return;
    setState(() {
      _history.removeAt(index);
      _selectedItems.remove(itemToRemove);
      if (_currentlyPlayingPath == audioPath) {
        _currentlyPlayingPath = null;
        _isPlayingClip = false;
      }
    });
    await prefs.setStringList('song_history', _history);

    if (!kIsWeb && audioPath != null && audioPath.isNotEmpty) {
      try {
        final file = File(audioPath);
        if (await file.exists()) await file.delete();
      } catch (e) {
        debugPrint('Could not delete singing clip: $e');
      }
    }
  }

String _parseSongTitle(dynamic rawItem) {
  String str = rawItem.toString();
  if (str.trimLeft().startsWith('{')) {
    try {
      final parsed = jsonDecode(str);
      if (parsed is Map) {
        final explicitTitle = parsed['title']?.toString().trim() ?? '';
        if (explicitTitle.isNotEmpty) return explicitTitle;
        str = parsed['song']?.toString() ?? str;
      }
    } catch (_) {}
  }
  if (str.contains(' - ')) {
    return str.split(' - ').first.trim();
  }
  return str.trim();
}

String _parseArtist(dynamic rawItem) {
  String str = rawItem.toString();
  String title = _parseSongTitle(rawItem);

  if (str.trimLeft().startsWith('{')) {
    try {
      final parsed = jsonDecode(str);
      if (parsed is Map) {
        final explicitArtist =
            _sanitizeArtistName(parsed['artist']?.toString());
        if (explicitArtist.isNotEmpty) return explicitArtist;
        str = parsed['song']?.toString() ?? str;
      }
    } catch (_) {}
  }

  if (str.contains(' - ')) {
    final parts = str.split(' - ');
    if (parts.length > 1) {
      final parsedArtist =
          _sanitizeArtistName(parts.sublist(1).join(' - '));
      if (parsedArtist.isNotEmpty) return parsedArtist;
    }
  }

  final fallback = _fallbackArtistForTitle(title);
  return fallback.isNotEmpty ? fallback : t('unknown_artist');
}

String? _parseAudioPath(String rawItem) {
  if (rawItem.startsWith('{')) {
    try {
      final parsed = jsonDecode(rawItem);
      return parsed['audioPath'];
    } catch (_) {}
  }
  return null;
}

String? _parseAlbumCover(String rawItem) {
  if (rawItem.startsWith('{')) {
    try {
      final parsed = jsonDecode(rawItem);
      return parsed['albumCover'] ?? parsed['imageUrl'];
    } catch (_) {}
  }
  return null;
}

String? _parseAppleMusicUrl(String rawItem) {
  if (rawItem.trimLeft().startsWith('{')) {
    try {
      final parsed = jsonDecode(rawItem);
      if (parsed is Map) {
        final value =
            parsed['appleMusicUrl'] ?? parsed['apple_music_url'];
        final url = value?.toString().trim() ?? '';
        if (url.isNotEmpty) return url;
      }
    } catch (_) {}
  }
  return null;
}

bool _parseFoundOffline(String rawItem) {
  if (rawItem.startsWith('{')) {
    try {
      final parsed = jsonDecode(rawItem);
      return parsed is Map && parsed['foundOffline'] == true;
    } catch (_) {}
  }
  return false;
}

Future<void> _openSongInPreferredApp(String title, [String artist = '']) async {
  final prefs = await SharedPreferences.getInstance();
  final preferredApp = prefs.getString('preferred_music_app') ?? 'spotify';
  final query = artist.trim().isEmpty ? title : '$title $artist';
  final encoded = Uri.encodeComponent(query);

  final Uri targetUrl = preferredApp == 'apple_music'
      ? Uri.parse("https://music.apple.com/us/search?term=$encoded")
      : Uri.parse("https://open.spotify.com/search/$encoded");

  if (await canLaunchUrl(targetUrl)) {
    await launchUrl(targetUrl, mode: LaunchMode.externalApplication);
  }
}

Future<void> _togglePlayClip(String? path) async {
  if (path == null || path.isEmpty) return;
  if (!kIsWeb) {
    try {
      if (!await File(path).exists()) return;
    } catch (_) {
      return;
    }
  }

  if (_isPlayingClip && _currentlyPlayingPath == path) {
    await _clipPlayer.pause();
    if (mounted) {
      setState(() {
        _isPlayingClip = false;
      });
    }
  } else {
    await _clipPlayer.stop();
    await _clipPlayer.play(DeviceFileSource(path));
    if (mounted) {
      setState(() {
        _currentlyPlayingPath = path;
        _isPlayingClip = true;
      });
    }
  }
}

  Future<void> _openCreatedSpotifyPlaylist(String playlistId) async {
    final nativeUri = Uri.parse('spotify:playlist:$playlistId');
    try {
      if (await canLaunchUrl(nativeUri)) {
        await launchUrl(nativeUri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}

    // Spotify's HTTPS playlist link is also a universal link, so devices with
    // Spotify installed can still hand it directly to the app.
    final webUri =
        Uri.parse('https://open.spotify.com/playlist/$playlistId');
    if (await canLaunchUrl(webUri)) {
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _exportToSpotify() async {
    final selectedTitles = _selectedItems
        .map((item) {
          final title = _parseSongTitle(item);
          final artist = _parseArtist(item);
          return artist.isEmpty ? title : '$title $artist';
        })
        .where((query) => query.trim().isNotEmpty)
        .toList();

    if (selectedTitles.isEmpty) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t('auth_spotify'))),
    );

    final spotifyService = SpotifyService();
    final token = await spotifyService.authenticate();

    if (token == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t('auth_failed'))),
        );
      }
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('creating_playlist'))),
      );
    }

    final playlistId = await spotifyService.createPlaylistFromHistory(
      token,
      selectedTitles,
      t,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          playlistId != null
              ? t('playlist_success')
              : t('playlist_error'),
        ),
      ),
    );

    if (playlistId != null) {
      await _openCreatedSpotifyPlaylist(playlistId);
    }
  }

  Future<void> _exportToAppleMusic() async {
    final selectedSongs = _selectedItems
        .map((item) {
          final title = _parseSongTitle(item).trim();
          final artist = _parseArtist(item).trim();
          return <String, String>{
            'title': title,
            'artist': artist,
            'appleMusicUrl': _parseAppleMusicUrl(item) ?? '',
          };
        })
        .where((song) => song['title']!.isNotEmpty)
        .toList(growable: false);

    final messenger = ScaffoldMessenger.of(context);

    if (selectedSongs.isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text(t('select_song_for_playlist'))),
      );
      return;
    }

    if (kIsWeb || !Platform.isIOS) {
      messenger.showSnackBar(
        SnackBar(content: Text(t('apple_playlist_error'))),
      );
      return;
    }

    messenger.showSnackBar(
      SnackBar(content: Text(t('apple_music_connecting'))),
    );

    try {
      final dynamic rawResult =
          await _recztAppleMusicChannel.invokeMethod<dynamic>(
        'createPlaylist',
        <String, dynamic>{
          'name': t('playlist_name'),
          'description': t('playlist_desc'),
          'songs': selectedSongs,
        },
      );

      final resultMap = rawResult is Map
          ? Map<String, dynamic>.from(rawResult)
          : <String, dynamic>{};

      final bool success = resultMap['success'] == true;
      final int addedCount =
          (resultMap['addedCount'] as num?)?.toInt() ?? 0;
      final int failedCount =
          (resultMap['failedCount'] as num?)?.toInt() ?? 0;
      final String playlistUrl =
          resultMap['playlistUrl']?.toString().trim() ?? '';

      if (!mounted) return;

      if (!success) {
        messenger.showSnackBar(
          SnackBar(content: Text(t('apple_playlist_error'))),
        );
        return;
      }

      if (failedCount > 0) {
        final message = t('apple_playlist_partial')
            .replaceAll('{added}', addedCount.toString())
            .replaceAll('{failed}', failedCount.toString());
        messenger.showSnackBar(SnackBar(content: Text(message)));
      } else {
        messenger.showSnackBar(
          SnackBar(content: Text(t('apple_playlist_success'))),
        );
      }

      if (playlistUrl.isNotEmpty) {
        final uri = Uri.tryParse(playlistUrl);
        if (uri != null && await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }
    } on MissingPluginException catch (e) {
      debugPrint('Apple Music playlist bridge is unavailable: $e');
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(t('apple_playlist_error'))),
      );
    } on PlatformException catch (e) {
      debugPrint(
        'Apple Music playlist creation failed (${e.code}): ${e.message}',
      );
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(t('apple_playlist_error'))),
      );
    } catch (e) {
      debugPrint('Apple Music playlist creation failed: $e');
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(t('apple_playlist_error'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool hasContent = _history.isNotEmpty || _pendingQueue.isNotEmpty;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(t('history_title')),
        centerTitle: true,
        actions: [
          if (_history.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: t('clear_history'),
              onPressed: () => _showClearHistoryDialog(context),
            ),
        ],
      ),
      body: !hasContent
          ? Center(
              child: Text(
                t('no_history'),
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          : CustomScrollView(
              slivers: [
                if (_pendingQueue.isNotEmpty) ...[
                  SliverToBoxAdapter(child: _buildSectionHeader(t('pending_queue_title'), isDark ? Colors.orangeAccent : Colors.orange)),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _buildPendingQueueCard(_pendingQueue[index], isDark),
                      childCount: _pendingQueue.length,
                    ),
                  ),
                  const SliverToBoxAdapter(
                    child: Divider(height: 30, indent: 16, endIndent: 16),
                  ),
                ],
                if (_history.isNotEmpty) ...[
                  SliverToBoxAdapter(child: _buildSectionHeader(t('history_title'), Theme.of(context).colorScheme.primary)),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _buildHistoryTile(index),
                      childCount: _history.length,
                    ),
                  ),
                ],
              ],
            ),
      bottomNavigationBar: _history.isEmpty ? null : _buildExportSection(),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Text(
        title,
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  Widget _buildPendingQueueCard(dynamic queueItem, bool isDark) {
    return Card(
      color: isDark ? Colors.grey[850] : Colors.orange.shade50,
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Colors.orange,
          child: Icon(Icons.sync, color: Colors.white),
        ),
        title: Text(
          t('processing_saved_recording'),
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

Widget _buildHistoryTile(int index) {
  final rawItem = _history[index];
  final songTitle = _parseSongTitle(rawItem);
  final artist = _parseArtist(rawItem);
  final audioClipPath = _parseAudioPath(rawItem);
  final bool foundOffline = _parseFoundOffline(rawItem);
  // Avoid synchronous disk I/O while Flutter is building a scrolling list.
  // The real existence check happens only if the play button is tapped.
  final bool clipExists = audioClipPath != null && audioClipPath.isNotEmpty;
  final bool isSelected = _selectedItems.contains(rawItem);

  return Dismissible(
    key: Key('${rawItem}_$index'),
    direction: DismissDirection.endToStart,
    background: Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20),
      color: Colors.redAccent,
      child: const Icon(Icons.delete, color: Colors.white),
    ),
    onDismissed: (_) => _deleteHistoryItem(index),
    child: Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: foundOffline
            ? BorderSide(color: Colors.orange.shade600, width: 1.5)
            : BorderSide.none,
      ),
      child: ListTile(
        onTap: () => _openSongInPreferredApp(songTitle, artist),
        leading: IconButton(
          icon: Icon(
            isSelected ? Icons.check_circle : Icons.check_circle_outline,
            color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey,
          ),
          onPressed: () {
            setState(() {
              isSelected ? _selectedItems.remove(rawItem) : _selectedItems.add(rawItem);
            });
          },
        ),
        title: Text(songTitle, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (artist.isNotEmpty)
              Text(
                '${t('by')} $artist',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            if (foundOffline)
              Padding(
                padding: const EdgeInsets.only(top: 3, bottom: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.cloud_done_outlined,
                      size: 13,
                      color: Colors.orange.shade700,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        t('found_offline_badge'),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.orange.shade800,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Text(
              t('tap_to_play_preferred'),
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (clipExists)
              IconButton(
                icon: Icon(
                  (_currentlyPlayingPath == audioClipPath && _isPlayingClip)
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_fill,
                  color: Theme.of(context).colorScheme.primary,
                  size: 28,
                ),
                tooltip: t('play_singing_sample'),
                onPressed: () => _togglePlayClip(audioClipPath),
              ),
            IconButton(
              icon: Icon(Icons.share, color: Theme.of(context).colorScheme.primary),
              tooltip: t('quickshare_tooltip'),
              onPressed: () => QuickShareHelper.showSongShareSheet(
                context,
                lang: widget.lang,
                title: songTitle,
                artist: _parseArtist(rawItem),
                coverUrl: _parseAlbumCover(rawItem),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  void _showClearHistoryDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t('clear_history')),
        content: Text(t('clear_history_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t('cancel')),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _clearHistory();
            },
            child: Text(
              t('clear'),
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExportSection() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1DB954),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _exportToSpotify,
            icon: const Icon(Icons.playlist_add),
            label: Text(t('create_spotify_playlist')),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFA243C),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _exportToAppleMusic,
            icon: const Icon(Icons.playlist_add),
            label: Text(t('create_apple_playlist')),
          ),
        ],
      ),
    );
  }
}
// ----------------------------------------------------
// LANGUAGE & STRICT METADATA MATCHING UTILITY
// ----------------------------------------------------
class LanguageMatcher {
  static const Map<String, String> _aliases = {
    'english': 'en', 'eng': 'en',
    'spanish': 'es', 'español': 'es', 'spa': 'es',
    'french': 'fr', 'français': 'fr', 'fra': 'fr', 'fre': 'fr',
    'german': 'de', 'deutsch': 'de', 'deu': 'de', 'ger': 'de',
    'italian': 'it', 'italiano': 'it', 'ita': 'it',
    'portuguese': 'pt', 'português': 'pt', 'por': 'pt',
    'japanese': 'ja', '日本語': 'ja', 'jpn': 'ja',
    'korean': 'ko', '한국어': 'ko', 'kor': 'ko',
    'chinese': 'zh', 'mandarin': 'zh', '中文': 'zh', 'zho': 'zh', 'chi': 'zh',
    'hindi': 'hi', 'हिन्दी': 'hi', 'hin': 'hi',
    'russian': 'ru', 'русский': 'ru', 'rus': 'ru',
    'turkish': 'tr', 'türkçe': 'tr', 'tur': 'tr',
    'arabic': 'ar', 'العربية': 'ar', 'ara': 'ar',
    'dutch': 'nl', 'nederlands': 'nl', 'nld': 'nl', 'dut': 'nl',
    'polish': 'pl', 'polski': 'pl', 'pol': 'pl',
    'unknown': '', 'undetermined': '', 'und': '',
  };

  static String normalizeLanguage(String lang) {
    final cleaned = lang.toLowerCase().trim().replaceAll('_', '-');
    if (cleaned.isEmpty) return '';
    final alias = _aliases[cleaned];
    if (alias != null) return alias;
    if (cleaned == 'zxx' || cleaned == 'un') return cleaned;

    final firstPart = cleaned.split('-').first;
    final partAlias = _aliases[firstPart];
    if (partAlias != null) return partAlias;
    if (RegExp(r'^[a-z]{2}$').hasMatch(firstPart)) return firstPart;
    return '';
  }

  static bool isLanguageMatch({
    required String userLanguage,
    required String trackLanguage,
    bool allowUnknown = true,
  }) {
    final userCode = normalizeLanguage(userLanguage);
    final trackCode = normalizeLanguage(trackLanguage);
    if (userCode.isNotEmpty && userCode == trackCode) return true;
    if (allowUnknown &&
        (trackCode.isEmpty || trackCode == 'un' || trackCode == 'zxx')) {
      return true;
    }
    return false;
  }

  static bool isValidOriginalSong(Map<String, dynamic> trackData) {
    final String title = (trackData['title'] ?? trackData['name'] ?? '')
        .toString()
        .toLowerCase();

    String artist = (trackData['artist'] ?? '').toString().toLowerCase();
    if (artist.isEmpty && trackData['artists'] is List) {
      final artists = trackData['artists'] as List;
      if (artists.isNotEmpty) {
        final first = artists.first;
        artist = (first is Map ? first['name'] : first)
                ?.toString()
                .toLowerCase() ??
            '';
      }
    }

    String album = '';
    final rawAlbum = trackData['album'];
    if (rawAlbum is Map) {
      album = (rawAlbum['name'] ?? rawAlbum['title'] ?? '')
          .toString()
          .toLowerCase();
    } else if (rawAlbum != null) {
      album = rawAlbum.toString().toLowerCase();
    }

    final combined = '$title $artist $album';
    const stronglyBlocked = <String>[
      'karaoke',
      'tribute',
      'tribute to',
      'in the style of',
      'made famous by',
      'as made famous by',
      'originally performed by',
      'sound alike',
      'sound-alike',
      'backing track',
      'backing vocals',
      'instrumental version',
      'workout mix',
      'fitness version',
      'nightcore',
      'sped up',
      'speed up',
      'slowed',
      'slowed down',
      '8d audio',
      'reverb version',
      'reverbed',
    ];
    for (final phrase in stronglyBlocked) {
      if (combined.contains(phrase)) return false;
    }

    // Avoid false positives such as a legitimate song whose title simply
    // contains the word "cover". Only reject cover/remake when they look like
    // edition descriptors.
    final descriptor = RegExp(
      r'(\(|\[|\-|–|—|:)\s*(cover|remake)(\s+version)?\b|\b(cover|remake)\s+version\b',
      caseSensitive: false,
    );
    if (descriptor.hasMatch(combined)) return false;

    // Keep legitimate, well-known remixes eligible, but reject phrases that
    // almost always indicate a novelty / derivative upload rather than the
    // main commercial release.
    final noveltyDescriptor = RegExp(
      r'(\(|\[|\-|–|—|:)\s*(nightcore|sped\s*up|slowed(?:\s*down)?|8d\s*audio|reverb(?:ed)?|workout\s*mix|fitness\s*version)\b',
      caseSensitive: false,
    );
    if (noveltyDescriptor.hasMatch(combined)) return false;

    return title.trim().isNotEmpty;
  }

  static List<T> filterResultsByLanguage<T extends Map<String, dynamic>>({
    required List<T> results,
    required String selectedLanguage,
    required String Function(T) getLanguage,
    required EnvironmentMode mode,
  }) {
    return results.where((item) {
      return isLanguageMatch(
        userLanguage: selectedLanguage,
        trackLanguage: getLanguage(item),
        allowUnknown: true,
      );
    }).toList();
  }
}
// --------------------------------------------------------------------
// 🎵 UNIFIED SONG SHARE CARD
// Used for the main-screen match banner, the history list, and any other
// individual-song quickshare — same graphics card everywhere.
// --------------------------------------------------------------------
class SongShareCard extends StatelessWidget {
  final String title;
  final String artist;
  final String? coverUrl;
  final Color themeColor;
  final String brandLabel;
  final VoidCallback onBrandTap;

  const SongShareCard({
    super.key,
    required this.title,
    required this.artist,
    required this.themeColor,
    required this.brandLabel,
    required this.onBrandTap,
    this.coverUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            themeColor.withValues(alpha: 0.85),
            const Color(0xFF121212),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: themeColor.withValues(alpha: 0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: themeColor.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Album Cover
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: (coverUrl != null && coverUrl!.isNotEmpty)
                ? Image.network(
                    coverUrl!,
                    width: 180,
                    height: 180,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _placeholder(),
                  )
                : _placeholder(),
          ),
          const SizedBox(height: 20),

          // Song Title
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),

          // Artist Name
          Text(
            artist,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 20),

          // Reczt App Badge Link
          InkWell(
            onTap: onBrandTap,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white30, width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.open_in_new_rounded, size: 14, color: Colors.white70),
                  const SizedBox(width: 6),
                  Text(
                    brandLabel,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.8,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      width: 180,
      height: 180,
      color: Colors.white10,
      child: const Icon(Icons.music_note, size: 64, color: Colors.white54),
    );
  }
}

class QuickShareHelper {
  /// Shows a themed preview of [SongShareCard] in a bottom sheet, then lets
  /// the user capture + share it. This is the single place that handles
  /// "quickshare a song" — called from the main-screen match banner and
  /// from the history list so the card always looks the same everywhere.
  static Future<void> showSongShareSheet(
    BuildContext context, {
    required String lang,
    required String title,
    required String artist,
    String? coverUrl,
  }) async {
    String tt(String key) =>
        localizedStrings[lang]?[key] ?? localizedStrings['en']?[key] ?? key;

    final themeColor = Theme.of(context).colorScheme.primary;
    final GlobalKey previewKey = GlobalKey();

    String? resolvedCover = coverUrl;
    if (resolvedCover == null || resolvedCover.isEmpty) {
      resolvedCover = await fetchAlbumArtwork('$title $artist');
    }

    final String displayArtist = artist.isNotEmpty ? artist : tt('unknown_artist');

    Future<void> captureAndShare() async {
      final shareText = tt('share_text')
          .replaceAll('{title}', title)
          .replaceAll('{artist}', displayArtist);

      final previewPath = await _captureRichSharePreview(
        previewKey,
        'reczt_song_link_preview.png',
      );

      await shareRecztInteractiveCard(
        context: context,
        title: '$title — $displayArtist',
        message: shareText,
        previewImagePath: previewPath,
      );
    }

    if (!context.mounted) return;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (modalContext) {
        return Container(
          padding: const EdgeInsets.all(24.0),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                RepaintBoundary(
                  key: previewKey,
                  child: SongShareCard(
                    title: title,
                    artist: displayArtist,
                    coverUrl: resolvedCover,
                    themeColor: themeColor,
                    brandLabel: 'Reczt',
                    onBrandTap: () async {
                      final uri = Uri.parse(reczAppStoreUrl);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
                  ),
                ),
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: themeColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: captureAndShare,
                    icon: const Icon(Icons.share, color: Colors.white),
                    label: Text(
                      tt('share_card'),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
