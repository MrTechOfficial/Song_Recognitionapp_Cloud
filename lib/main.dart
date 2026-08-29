import 'dart:async';
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';  



// --------------------------------------------------------------------
// 🔗 SHARED APP CONSTANTS & HELPERS
// --------------------------------------------------------------------

/// Single source of truth for the Reczt App Store link. Previously this
/// was redeclared locally in several functions — consolidated here.
const String reczAppStoreUrl = "https://apps.apple.com/app/id123456789";


/// Native iOS channel used to share a true tappable Link Presentation card.
/// If the native iOS helper is not installed, sharing falls back to a normal
/// text + URL share so the feature still works on every platform.
const MethodChannel _recztRichShareChannel = MethodChannel('reczt/rich_share');

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
/// Returns null if location services or permissions are unavailable.
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

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  } catch (e) {
    debugPrint('Error fetching device location: $e');
    return null;
  }
}

/// Lightweight metadata returned by the iTunes Search API.
/// Reczt uses this only as a metadata fallback after recognition; recognition
/// itself still comes from your existing backend / ACRCloud pipeline.
class _SongLookupMetadata {
  final String? artworkUrl;
  final String? genre;

  const _SongLookupMetadata({this.artworkUrl, this.genre});
}

String _normalizeGenre(String? rawGenre) {
  final value = (rawGenre ?? '').toLowerCase().trim();
  if (value.isEmpty) return 'other';
  if (value.contains('rock')) return 'rock';
  if (value.contains('jazz') || value.contains('blues')) return 'jazz';
  if (value.contains('alternative') || value.contains('indie') || value.contains('singer/songwriter')) return 'indie';
  if (value.contains('hip-hop') || value.contains('hip hop') || value.contains('rap')) return 'rap';
  if (value.contains('classical') || value.contains('orchestra')) return 'classical';
  if (value.contains('reggae')) return 'reggae';
  if (value.contains('r&b') || value.contains('rnb') || value.contains('soul')) return 'r&b';
  if (value.contains('pop')) return 'pop';
  return 'other';
}

String _normalizeEmotion(String? rawEmotion) {
  final value = (rawEmotion ?? '').toLowerCase().trim();
  if (value.contains('sad') || value.contains('melanch') || value.contains('blue')) return 'sad';
  if (value.contains('hype') || value.contains('energetic') || value.contains('excited') || value.contains('party')) return 'hype';
  if (value.contains('romantic') || value.contains('love') || value.contains('tender')) return 'romantic';
  return 'happy';
}

/// Fetches artwork and a real catalog genre rather than guessing genre from
/// words in the song title. The call is short-timeout so it never holds up
/// recognition for long if Apple's metadata service is unavailable.
Future<_SongLookupMetadata> fetchSongMetadata(String query) async {
  try {
    final encoded = Uri.encodeComponent(query);
    final url = Uri.parse(
      'https://itunes.apple.com/search?term=$encoded&entity=song&limit=5',
    );
    final response = await http.get(url).timeout(const Duration(seconds: 8));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final results = data['results'];
      if (results is List && results.isNotEmpty) {
        final first = Map<String, dynamic>.from(results.first as Map);
        final artwork = (first['artworkUrl100'] ?? '').toString();
        final rawGenre = first['primaryGenreName']?.toString();
        return _SongLookupMetadata(
          artworkUrl: artwork.isEmpty
              ? null
              : artwork.replaceAll('100x100bb', '600x600bb'),
          genre: rawGenre == null ? null : _normalizeGenre(rawGenre),
        );
      }
    }
  } catch (e) {
    debugPrint('Error fetching song metadata: $e');
  }
  return const _SongLookupMetadata();
}

/// Kept as a compatibility helper for the existing QuickShare code.
Future<String?> fetchAlbumArtwork(String query) async {
  return (await fetchSongMetadata(query)).artworkUrl;
}

/// Compatibility wrappers retained so older call sites do not break.
/// Analytics no longer guesses genre or emotion from title keywords.
String inferGenreFromTitle(String title) => 'other';
String refineEmotionFromTitle(String title, String backendEmotion) =>
    _normalizeEmotion(backendEmotion);

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
  const NotificationDetails details = NotificationDetails(android: androidDetails);

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
    'app_title': 'Hands-Free Song Identifier',
    'where_are_you': 'Where Are You?',
    'quiet_room': 'A quiet room',
    'loud_room': 'A loud room with background noise',
    'initial_status': 'Select your environment and tap the mic or Say "Hey Siri, Activate Reczt"!',
    'listening': 'Listening...',
    'searching': 'Searching database...',
    'match_found': 'Match Found!',
    'mic_denied': 'Microphone permission denied.',
    'settings_title': 'App Preferences',
    'pref_music_app': 'Preferred Music App (Please note: choosing Spotify will give you access to more in-depth recommendations of Spotify songs and playlists)',
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
    'step 1': 'Configure Your Settings',
    'step1_desc': 'Select your preferred music platform and language.',
    'step 2': 'Where Are You?',
    'step2_desc': 'Click the button that corresponds to your environment. These buttons determine how long the app will listen for music.',
    'step 3': 'Sing',
    'step3_desc': 'Click the microphone button or say "Hey Siri, Activate Reczt" to begin the song recognition process.',
    'step 4': 'Enjoy Your Music!',
    'step4_desc': 'Once a song is recognized, you can play it directly in your preferred music app.',
    'step 5': 'View Your History',
    'step5_desc': 'Can\'t remember the song you just listened to? View your search history by clicking the clock icon on the main page of Reczt.',
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
      'vibe_match_playlist': 'Bi-Weekly Vibe Match Playlist',
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
    'app_title': 'Identificador de Canciones',
    'where_are_you': '¿Dónde estás?',
    'quiet_room': 'Una habitación silenciosa',
    'loud_room': 'Una habitación ruidosa con ruido de fondo',
    'initial_status': 'Selecciona tu entorno y toca el micrófono o di: "Oye Siri, activa Reczt".' ,
    'listening': 'Escuchando...',
    'searching': 'Buscando en la base de datos...',
    'match_found': '¡Coincidencia encontrada!',
    'mic_denied': 'Permiso de micrófono denegado.',
    'settings_title': 'Preferencias de la aplicación',
    'pref_music_app': 'Aplicación de música preferida (Nota: elegir Spotify te dará acceso a recomendaciones más detalladas de canciones y listas de reproducción de Spotify)',    'pref_lang': 'Idioma preferido',
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
    'step 1': 'Paso 1: Configura tus ajustes',
    'step1_desc': 'Selecciona tu plataforma de música y idioma preferidos.',
    'step 2': 'Paso 2: ¿Dónde estás?',
    'step2_desc': 'Haz clic en el botón que corresponde a tu entorno. Estos botones determinan cuánto tiempo escuchará la aplicación música.',
    'step 3': 'Paso 3: ¡Canta!',
    'step3_desc': 'Presiona el tallo de tus AirPods o haz clic en el botón del micrófono para comenzar el proceso de reconocimiento de canciones.',
    'step 4': 'Paso 4: ¡Disfruta tu música!',
    'step4_desc': 'Una vez que se reconozca una canción, puedes reproducirla directamente en tu aplicación de música preferida.',
    'step 5': 'Paso 5: Ver tu historial',
    'step5_desc': '¿No recuerdas la canción que acabas de escuchar? Puedes ver tu historial de búsqueda haciendo clic en el icono del reloj en la página principal de Reczt.',
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
      'vibe_match_playlist': 'Lista de reproducción de coincidencias de vibe cada dos semanas',
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
    'app_title': 'Identificateur de Chansons',
    'where_are_you': 'Où êtes-vous ?',
    'quiet_room': 'Une pièce calme',
    'loud_room': 'Une pièce bruyante avec du bruit de fond',
    'initial_status': 'Sélectionnez votre environnement et appuyez sur le micro, ou dites "Dis Siri, active Reczt"!.',
    'listening': 'Écoute en cours...',
    'searching': 'Recherche dans la base de données...',
    'match_found': 'Correspondance trouvée !',
    'mic_denied': 'Autorisation du microphone refusée.',
    'settings_title': 'Préférences de l\'application',
    'pref_music_app': 'Application de musique préférée (Remarque : choisir Spotify vous donnera accès à des recommandations plus détaillées de morceaux et playlists Spotify)',    'pref_lang': 'Langue préférée',
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
    'step 1': 'Étape 1 : Configurez vos paramètres',
    'step1_desc': 'Sélectionnez votre plateforme musicale et votre langue préférées.',
    'step 2': 'Étape 2 : Où êtes-vous ?',
    'step2_desc': 'Cliquez sur le bouton correspondant à votre environnement. Ces boutons déterminent combien de temps l\'application écoutera la musique.',
    'step 3': 'Étape 3 : Chantez !',
    'step3_desc': 'Cliquez sur le bouton du microphone ou dites « Hey Siri, Activate Reczt » pour lancer le processus de reconnaissance de la chanson.',
    'step 4': 'Étape 4 : Profitez de votre musique !',
    'step4_desc': 'Une fois qu\'une chanson est reconnue, vous pouvez la lire directement dans votre application musicale préférée.',
    'step 5': 'Étape 5 : Consultez votre historique',
    'step5_desc': 'Vous ne vous souvenez pas de la chanson que vous venez d\'écouter ? Vous pouvez consulter votre historique de recherche en cliquant sur l\'icône de l\'horloge sur la page principale de Reczt.',
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
      'vibe_match_playlist': 'Playlist Vibe Match bi-hebdomadaire',
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
    'app_title': 'Song-Erkennung',
    'where_are_you': 'Wo bist du?',
    'quiet_room': 'Ein ruhiger Raum',
    'loud_room': 'Ein lauter Raum mit Hintergrundgeräuschen',
    'initial_status': 'Wähle deine Umgebung aus und tippe auf das Mikrofon oder sage: "Hey Siri, aktiviere Reczt"!',
    'listening': 'Zuhören...',
    'searching': 'Datenbank wird durchsucht...',
    'match_found': 'Treffer gefunden!',
    'mic_denied': 'Mikrofonberechtigung verweigert.',
    'settings_title': 'App-Einstellungen',
    'pref_music_app': 'Bevorzugte Musik-App (Hinweis: Wenn Sie Spotify wählen, erhalten Sie ausführlichere Empfehlungen für Spotify-Titel und -Playlists)',    'pref_lang': 'Bevorzugte Sprache',
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
    'step 1': 'Schritt 1: Konfiguriere deine Einstellungen',
    'step1_desc': 'Wähle deine bevorzugte Musikplattform und Sprache aus.',
    'step 2': 'Schritt 2: Wo bist du?',
    'step2_desc': 'Klicke auf die Schaltfläche, die deiner Umgebung entspricht. Diese Schaltflächen bestimmen, wie lange die App Musik hören wird.',
    'step 3': 'Schritt 3: Singe!',
    'step3_desc': 'Klicken Sie auf die Mikrofontaste oder sagen Sie „Hey Siri, aktiviere Reczt“, um die Songerkennung zu starten.',
    'step 4': 'Schritt 4: Genieße deine Musik!',
    'step4_desc': 'Sobald ein Song erkannt wurde, kannst du ihn direkt in deiner bevorzugten Musik-App abspielen.',
    'step 5': 'Schritt 5: Sieh dir deinen Verlauf an',
    'step5_desc': 'Kannst du dich nicht an den Song erinnern, den du gerade gehört hast? Sieh dir deinen Suchverlauf an, indem du auf das Uhrensymbol auf der Hauptseite von Reczt klickst.',
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
      'vibe_match_playlist': 'Zweiwöchentliche Vibe-Match-Playlist',
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
    'app_title': 'Riconoscimento Brani',
    'where_are_you': 'Dove ti trovi?',
    'quiet_room': 'Una stanza silenziosa',
    'loud_room': 'Una stanza rumorosa',
    'initial_status': 'Seleziona l\'ambiente e tocca il microfono o dicci: "Hey Siri, attiva Reczt"!',
    'listening': 'Ascolto in corso...',
    'searching': 'Ricerca nel database...',
    'match_found': 'Brano trovato!',
    'mic_denied': 'Autorizzazione microfono negata.',
    'settings_title': 'Preferenze App',
    'pref_music_app': 'App musicale preferita (Nota: scegliendo Spotify avrai accesso a consigli più approfonditi su brani e playlist di Spotify)',    'pref_lang': 'Lingua preferita',
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
    'step 1': 'Passo 1: Configura le tue impostazioni',
    'step1_desc': 'Seleziona la tua piattaforma musicale e lingua preferita.',
    'step 2': 'Passo 2: Dove ti trovi?',
    'step2_desc': 'Clicca sul pulsante che corrisponde al tuo ambiente. Questi pulsanti determinano per quanto tempo l\'app ascolterà la musica.',
    'step 3': 'Passo 3: Canta!',
    'step3_desc': 'Clicca sul pulsante del microfono o dì "Hey Siri, attiva Reczt" per avviare il processo di riconoscimento del brano.',
    'step 4': 'Passo 4: Goditi la tua musica!',
    'step4_desc': 'Una volta riconosciuta una canzone, puoi riprodurla direttamente nella tua app musicale preferita.',
    'step 5': 'Passo 5: Visualizza la tua cronologia',
    'step5_desc': 'Non ricordi la canzone che hai appena ascoltato? Visualizza la cronologia delle ricerche cliccando sull\'icona dell\'orologio nella pagina principale di Reczt.',
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
      'vibe_match_playlist': 'Playlist di corrispondenza Vibe bisettimanale',
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
    'app_title': 'Identificador de Músicas',
    'where_are_you': 'Onde você está?',
    'quiet_room': 'Um quarto silencioso',
    'loud_room': 'Um ambiente barulhento',
    'initial_status': 'Selecione seu ambiente e toque no microfone ou diga: "Oye Siri, ative Reczt"!',
    'listening': 'Ouvindo...',
    'searching': 'Buscando no banco de dados...',
    'match_found': 'Música encontrada!',
    'mic_denied': 'Permissão do microfone negada.',
    'settings_title': 'Preferências do App',
    'pref_music_app': 'Aplicativo de música preferido (Nota: escolher o Spotify dará acesso a recomendações mais detalhadas de músicas e playlists do Spotify)',    'pref_lang': 'Idioma preferido',
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
    'step 1': 'Passo 1: Configure suas preferências',
    'step1_desc': 'Selecione sua plataforma musical e idioma preferido.',
    'step 2': 'Passo 2: Onde você está?',
    'step2_desc': 'Clique no botão que corresponde ao seu ambiente. Esses botões determinam por quanto tempo o app ouvirá a música.',
    'step 3': 'Passo 3: Cante!',
    'step3_desc': 'Clique no botão do microfone ou diga "Hey Siri, Activate Reczt" para iniciar o processo de reconhecimento da música.',
    'step 4': 'Passo 4: Aproveite sua música!',
    'step4_desc': 'Assim que uma música for reconhecida, você pode reproduzi-la diretamente em seu app musical preferido.',
    'step 5': 'Passo 5: Visualize seu histórico',
    'step5_desc': 'Não se lembra da música que acabou de ouvir? Visualize o histórico de buscas clicando no ícone do relógio na página principal do Reczt.',
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
      'vibe_match_playlist': 'Playlist de correspondência de vibe quinzenal',
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
    'app_title': '楽曲識別アプリ',
    'where_are_you': 'どこにいますか？',
    'quiet_room': '静かな部屋',
    'loud_room': '騒がしい場所',
    'initial_status': '環境を選択し、マイクをタップするか、「Hey Siri, Activate Reczt」と話しかけてください。',
    'listening': '聞き取り中...',
    'searching': 'データベースを検索中...',
    'match_found': '曲が見つかりました！',
    'mic_denied': 'マイクのアクセス許可が拒否されました。',
    'settings_title': 'アプリ設定',
    'pref_music_app': 'お気に入りの音楽アプリ（注：Spotifyを選択すると、Spotifyの曲やプレイリストのより詳細なおすすめ機能を利用できます）',    'pref_lang': '優先言語',
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
    'step 1': '手順 1: 設定を構成する',
    'step1_desc': 'お好みの音楽プラットフォームと言語を選択してください。',
    'step 2': '手順 2: どこにいますか？',
    'step2_desc': '環境に一致するボタンをクリックしてください。これらのボタンは、アプリが音楽を聞く時間を決定します。',
    'step 3': '手順 3: 歌ってください！',
    'step3_desc': 'マイクボタンをタップするか、「Hey Siri, Activate Reczt」と話しかけて、曲の認識を開始してください。',
    'step 4': '手順 4: 音楽をお楽しみください！',
    'step4_desc': '曲が認識されると、お好みの音楽アプリで直接再生できます。',
    'step 5': '手順 5: 履歴を表示する',
    'step5_desc': '最近聞いた曲が思い出せませんか？ Recztのメインページで時計アイコンをクリックして検索履歴を表示できます。',
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
    'app_title': '음악 검색 식별기',
    'where_are_you': '어디에 계신가요?',
    'quiet_room': '조용한 방',
    'loud_room': '시끄러운 장소',
    'initial_status': '환경을 선택한 뒤 마이크를 탭하거나 "Hey Siri, Activate Reczt"라고 말하세요!',
    'listening': '듣는 중...',
    'searching': '데이터베이스 검색 중...',
    'match_found': '곡을 찾았습니다!',
    'mic_denied': '마이크 권한이 거부되었습니다.',
    'settings_title': '앱 설정',
    'pref_music_app': '선호하는 음악 앱 (참고: Spotify를 선택하면 Spotify 노래 및 재생목록에 대한 더 심도 있는 추천을 받을 수 있습니다)',    'pref_lang': '선호하는 언어',
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
    'step 1': '1단계: 설정 구성',
    'step1_desc': '선호하는 음악 플랫폼과 언어를 선택하세요.',
    'step 2': '2단계: 어디에 계신가요?',
    'step2_desc': '환경에 해당하는 버튼을 클릭하세요. 이 버튼들은 앱이 음악을 듣는 시간을 결정합니다.',
    'step 3': '3단계: 노래 부르기',
    'step3_desc': '마이크 버튼을 누르거나 "Hey Siri, Reczt 활성화해 줘"라고 말하여 노래 인식 과정을 시작하세요.',
    'step 4': '4단계: 음악 즐기기!',
    'step4_desc': '노래가 인식되면 선호하는 음악 앱에서 직접 재생할 수 있습니다.',
    'step 5': '5단계: 기록 보기',
    'step5_desc': '방금 들은 노래가 기억나지 않나요? Reczt의 메인 페이지에서 시계 아이콘을 클릭하여 검색 기록을 확인할 수 있습니다.',
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
    'app_title': '歌曲识别器',
    'where_are_you': '你在哪里？',
    'quiet_room': '安静的房间',
    'loud_room': '吵闹的环境',
    'initial_status': '选择你的环境并点击麦克风，或者说：“嘿 Siri，激活 Reczt”！',
    'listening': '正在聆听...',
    'searching': '正在搜索数据库...',
    'match_found': '找到歌曲！',
    'mic_denied': '麦克风权限被拒绝。',
    'settings_title': '应用设置',
    'pref_music_app': '首选音乐应用（注：选择 Spotify 将为您提供关于 Spotify 歌曲和歌单的更深入推荐）',    'pref_lang': '首选语言',
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
    'step 1': '第一步：配置设置',
    'step1_desc': '请选择您偏好的音乐平台和语言。',
    'step 2': '第二步：您在哪里？',
    'step2_desc': '点击与您的环境相对应的按钮。这些按钮将决定应用程序聆听音乐的时间。',
    'step 3': '第三步：唱歌！',
    'step3_desc': '点击麦克风按钮或说“Hey Siri, Activate Reczt”以开始歌曲识别。',
    'step 4': '第四步：享受您的音乐！',
    'step4_desc': '一旦识别出歌曲，您就可以直接在您偏好的音乐应用中播放它。',
    'step 5': '第五步：查看历史记录',
    'step5_desc': '记不起刚听过的歌曲吗？在 Reczt 的主页面上点击时钟图标来查看搜索历史。',
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
    'app_title': 'गाना पहचानें',
    'where_are_you': 'आप कहाँ हैं?',
    'quiet_room': 'शांत कमरा',
    'loud_room': 'शोर-शराबे वाली जगह',
    'initial_status': 'अपना एनवायरनमेंट चुनें और माइक पर टैप करें या "Hey Siri, Activate Reczt" कहें!',
    'listening': 'सुन रहा है...',
    'searching': 'डेटाबेस में खोज रहा है...',
    'match_found': 'गाना मिल गया!',
    'mic_denied': 'माइक अनुमति अस्वीकृत।',
    'settings_title': 'ऐप प्राथमिकताएं',
    'pref_music_app': 'पसंदीदा संगीत ऐप (कृपया ध्यान दें: Spotify चुनने से आपको Spotify गानों और प्लेलिस्ट की अधिक विस्तृत सिफारिशें मिलेंगी)',    'pref_lang': 'पसंदीदा भाषा',
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
    'step 1': 'चरण 1: अपनी सेटिंग्स कॉन्फ़िगर करें',
    'step1_desc': 'अपनी पसंदीदा म्यूजिक प्लेटफ़ॉर्म और भाषा चुनें।',
    'step 2': 'चरण 2: आप कहाँ हैं?',
    'step2_desc': 'अपने वातावरण के अनुसार बटन पर क्लिक करें। ये बटन यह निर्धारित करते हैं कि ऐप कितनी देर तक संगीत सुनेगा।',
    'step 3': 'चरण 3: गाओ!',
    'step3_desc': 'गाने की पहचान करने की प्रक्रिया शुरू करने के लिए माइक्रोफ़ोन बटन पर क्लिक करें या "Hey Siri, Activate Reczt" कहें।',
    'step 4': 'चरण 4: अपने संगीत का आनंद लें!',
    'step4_desc': 'एक बार जब कोई गाना पहचाना जाता है, तो आप इसे सीधे अपनी पसंदीदा म्यूजिक ऐप में चला सकते हैं।',
    'step 5': 'चरण 5: अपना इतिहास देखें',
    'step5_desc': 'क्या आपको याद न हो कि आपने अभी कोई गाना सुना था? Reczt के मुख्य पृष्ठ पर घड़ी के आइकॉन के ऊपर click करके आप अपनी search history को view कर सकते हैं।',
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
      'vibe_match_playlist': 'हर दो हफ़्ते में आने वाली वाइब मैच प्लेलिस्ट',
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
    'app_title': 'Распознавание Музыки',
    'where_are_you': 'Где вы находитесь?',
    'quiet_room': 'Тихая комната',
    'loud_room': 'Шумное помещение',
    'initial_status': 'Выберите обстановку и нажмите на микрофон или скажите: "Hey Siri, Activate Reczt"!',
    'listening': 'Слушаю...',
    'searching': 'Поиск в базе данных...',
    'match_found': 'Песня найдена!',
    'mic_denied': 'Доступ к микрофону запрещен.',
    'settings_title': 'Настройки приложения',
    'pref_music_app': 'Предпочитаемое музыкальное приложение (Примечание: выбор Spotify даст доступ к более подробным рекомендациям треков и плейлистов Spotify)',    'pref_lang': 'Предпочитаемый язык',
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
    'step 1': 'Шаг 1: Настройте параметры',
    'step1_desc': 'Выберите предпочитаемую музыкальную платформу и язык.',
    'step 2': 'Шаг 2: Где вы находитесь?',
    'step2_desc': 'Нажмите кнопку, соответствующую вашей обстановке. Эти кнопки определяют, как долго приложение будет слушать музыку.',
    'step 3': 'Шаг 3: Пойте!',
    'step3_desc': 'Нажмите кнопку микрофона или скажите "Hey Siri, Activate Reczt", чтобы начать распознавание песни.',
    'step 4': 'Шаг 4: Наслаждайтесь музыкой!',
    'step4_desc': 'После распознавания песни вы можете воспроизвести ее напрямую в предпочитаемом музыкальном приложении.',
    'step 5': 'Шаг 5: Просмотр истории',
    'step5_desc': 'Не можете вспомнить песню, которую только что слушали? Просмотрите историю поиска, нажав на значок часов на главной странице Reczt.',
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
      'vibe_match_playlist': 'Би-недельный плейлист вибров совпадений',
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
    'app_title': 'Şarkı Tanıma',
    'where_are_you': 'Neredesiniz?',
    'quiet_room': 'Sessiz bir oda',
    'loud_room': 'Gürültülü bir ortam',
    'initial_status': 'Ortamınızı seçin ve mikrofona dokunun ya da "Hey Siri, Reczt\'i etkinleştir" deyin!',
    'listening': 'Dinleniyor...',
    'searching': 'Veritabanı aranıyor...',
    'match_found': 'Eşleşme Bulundu!',
    'mic_denied': 'Mikrofon izni reddedildi.',
    'settings_title': 'Uygulama Tercihleri',
    'pref_music_app': 'Tercih Edilen Müzik Uygulaması (Lütfen unutmayın: Spotify\'ı seçmek, Spotify şarkıları ve çalma listeleri hakkında daha ayrıntılı önerilere erişmenizi sağlar)',    'pref_lang': 'Tercih Edilen Dil',
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
    'step 1': 'Adım 1: Ayarlarınızı Yapılandırın',
    'step1_desc': 'Tercih ettiğiniz müzik platformunu ve dili seçin.',
    'step 2': 'Adım 2: Neredesiniz?',
    'step2_desc': 'Ortamınıza karşılık gelen düğmeye tıklayın. Bu düğmeler, uygulamanın müziği ne kadar süre dinleyeceğini belirler.',
    'step 3': 'Adım 3: Şarkı Söyleyin!',
    'step3_desc': 'Şarkı tanıma işlemini başlatmak için mikrofon düğmesine tıklayın veya "Hey Siri, Reczt\'i etkinleştir" deyin.',
    'step 4': 'Adım 4: Müziğinizin Tadını Çıkarın!',
    'step4_desc': 'Bir şarkı tanındığında, onu tercih ettiğiniz müzik uygulamasında doğrudan çalabilirsiniz.',
    'step 5': 'Adım 5: Geçmişinizi Görüntüleyin',
    'step5_desc': 'Az önce dinlediğiniz şarkıyı hatırlamıyor musunuz? Reczt ana sayfasındaki saat simgesine tıklayarak arama geçmişinizi görüntüleyebilirsiniz.',
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
      'vibe_match_playlist': 'İki Haftalık Ruh Hali Uyumu Çalma Listesi',
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
    'app_title': 'محدد الأغاني',
    'where_are_you': 'أين أنت؟',
    'quiet_room': 'غرفة هادئة',
    'loud_room': 'مكان صاخب',
    'initial_status': 'ابك واضغط على الميكروفوناختر البيئة الخاصة أو قُل: "Hey Siri, Activate Reczt!',
    'listening': 'جاري الاستماع...',
    'searching': 'جاري البحث...',
    'match_found': 'تم العثور على الأغنية!',
    'mic_denied': 'تم رفض إذن الميكروفون.',
    'settings_title': 'تفضيلات التطبيق',
    'pref_music_app': 'تطبيق الموسيقى المفضل (يرجى الملاحظة: اختيار Spotify سيمنحك إمكانية الوصول إلى توصيات أكثر تعمقًا لأغاني وقوائم تشغيل Spotify)',    'pref_lang': 'اللغة المفضلة',
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
    'step 1': 'الخطوة 1: تكوين إعداداتك',
    'step1_desc': 'حدد منصة الموسيقى واللغة المفضلة لديك.',
    'step 2': 'الخطوة 2: أين أنت؟',
    'step2_desc': 'انقر على الزر الذي يتوافق مع بيئتك. تحدد هذه الأزرار المدة التي ستستمع فيها التطبيق إلى الموسيقى.',
    'step 3': 'الخطوة 3: غنِ!',
    'step3_desc': 'اضغط على ساق AirPods الخاصة بك أو انقر على زر الميكروفون لبدء عملية التعرف على الأغاني.',
    'step 4': 'الخطوة 4: استمتع بموسيقاك!',
    'step4_desc': 'بمجرد التعرف على أغنية، يمكنك تشغيلها مباشرة في تطبيق الموسيقى المفضل لديك.',
    'step 5': 'الخطوة 5: عرض سجل البحث الخاص بك',
    'step5_desc': 'هل لا تتذكر الأغنية التي استمعت إليها للتو؟ يمكنك عرض سجل البحث الخاص بك بالنقر على أيقونة الساعة في الصفحة الرئيسية لتطبيق Reczt.',
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
  
    'waiting_for_voice': 'بانتظار صوتك...',
    'signal_good': 'الإشارة جيدة',
    'sing_louder': 'غنِّ بصوت أعلى قليلًا',
    'top_guesses_title': 'أفضل الاحتمالات',
    'top_guesses_subtitle': 'لست متأكدًا تمامًا. اضغط على الأغنية التي تقصدها.',
    'confidence': 'تطابق',
    'retry_search': 'إعادة محاولة آخر تسجيل',
    'search_timed_out': 'استغرق البحث وقتًا طويلًا. حاول مرة أخرى.',
    'stop_recording': 'إيقاف التسجيل',
    'other': 'أخرى',
  },
  'nl': {
    'app_title': 'Nummer Herkenner',
    'where_are_you': 'Waar ben je?',
    'quiet_room': 'Een stille ruimte',
    'loud_room': 'Een drukke ruimte',
    'initial_status': 'Selecteer je omgeving en tik op de microfoon of zeg: "Hey Siri, activeer Reczt"!',
    'listening': 'Luisteren...',
    'searching': 'Database zoeken...',
    'match_found': 'Nummer Gevonden!',
    'mic_denied': 'Microfoontoegang geweigerd.',
    'settings_title': 'App Voorkeuren',
    'pref_music_app': 'Voorkeursmuziek-app (Let op: het kiezen van Spotify geeft je toegang tot diepgaandere aanbevelingen voor Spotify-nummers en -afspeellijsten)',    'pref_lang': 'Voorkeurstaal',
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
    'step 1': 'Stap 1: Stel je voorkeuren in',
    'step1_desc': 'Selecteer je favoriete muziekplatform en taal.',
    'step 2': 'Stap 2: Waar ben je?',
    'step2_desc': 'Klik op de knop die overeenkomt met je omgeving. Deze knoppen bepalen hoe lang de app naar muziek zal luisteren.',
    'step 3': 'Stap 3: Zing!',
    'step3_desc': 'Klik op de microfoonknop of zeg "Hey Siri, activeer Reczt" om het nummerherkenningsproces te starten.',
    'step 4': 'Stap 4: Geniet van je muziek!',
    'step4_desc': 'Zodra een nummer is herkend, kun je het direct afspelen in je favoriete muziekapp.',
    'step 5': 'Stap 5: Bekijk je geschiedenis',
    'step5_desc': 'Kun je je niet herinneren welk nummer je net hebt gehoord? Je kunt je zoekgeschiedenis bekijken door op het klokpictogram op de startpagina van Reczt te klikken.',
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
      'vibe_match_playlist': 'Tweewekelijkse Vibe Match-playlist',
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
    'app_title': 'Rozpoznawanie Muzyki',
    'where_are_you': 'Gdzie jesteś?',
    'quiet_room': 'Ciche pomieszczenie',
    'loud_room': 'Głośne otoczenie',
    'initial_status': 'Wybierz swoje środowisko i stuknij w mikrofon lub powiedz Hej Siri, Aktywuj Reczt!',
    'listening': 'Słucham...',
    'searching': 'Wyszukiwanie w bazie...',
    'match_found': 'Znaleziono utwór!',
    'mic_denied': 'Odmowa dostępu do mikrofonu.',
    'settings_title': 'Preferencje Aplikacji',
    'pref_music_app': 'Preferowana aplikacja muzyczna (Uwaga: wybór Spotify zapewni dostęp do bardziej szczegółowych rekomendacji utworów i playlist Spotify)',    'pref_lang': 'Preferowany język',
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
    'step 1': 'Krok 1: Skonfiguruj ustawienia',
    'step1_desc': 'Wybierz preferowaną platformę muzyczną i język.',
    'step 2': 'Krok 2: Gdzie jesteś?',
    'step2_desc': 'Kliknij przycisk odpowiadający Twojemu otoczeniu. Te przyciski określają, jak długo aplikacja będzie słuchać muzyki.',
    'step 3': 'Krok 3: Śpiewaj!',
    'step3_desc': 'Kliknij przycisk mikrofonu lub powiedz „Hey Siri, Activate Reczt”, aby rozpocząć proces rozpoznawania utworu.',
    'step 4': 'Krok 4: Ciesz się muzyką!',
    'step4_desc': 'Po rozpoznaniu utworu możesz odtworzyć go bezpośrednio w preferowanej aplikacji muzycznej.',
    'step 5': 'Krok 5: Sprawdź swoją historię',
    'step5_desc': 'Nie pamiętasz, jaką piosenkę właśnie słuchałeś? Możesz sprawdzić historię wyszukiwania, klikając ikonę zegara na stronie głównej Reczt.',
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

enum EnvironmentMode {
  // ACRCloud humming/cover recognition generally benefits from a longer
  // melodic sample. Reczt still stops early when it has captured enough
  // usable singing, but these are the safe maximum listen windows.
  quiet(duration: 10, icon: Icons.king_bed, key: 'quiet_room'),
  loud(duration: 12, icon: Icons.volume_up, key: 'loud_room'),
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
    this.genre,
    this.emotion,
    this.spotifyUrl,
    this.appleMusicUrl,
    this.coverUrl,
  });

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

    return _SongMatchCandidate(
      raw: item,
      title: title.isEmpty ? 'Unknown Title' : title,
      artist: artist.isEmpty ? 'Unknown Artist' : artist,
      confidence: score,
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
        _isExplicitlyPausedForRecording = true;
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
    _amplitudeSubscription?.cancel();
    _connectivitySubscription?.cancel();
    if (!kIsWeb) {
      _siriChannel.setMethodCallHandler(null);
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
        unawaited(_checkPendingOfflineQueue());
      });
    }
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
  // Normalized map coordinates for locations displayed while singing.
  final List<Offset> _livePinLocations = <Offset>[];

  EnvironmentMode _selectedMode = EnvironmentMode.Outdoors;
  int _secondsRemaining = 12;
  Timer? _countdownTimer;

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
  Position? _sessionLocation;

  final String _backendUrl =
      'https://song-recognitionapp-cloud.onrender.com/recognize';

  String t(String key) {
    return localizedStrings[_selectedLanguage]?[key] ??
        localizedStrings['en']![key] ??
        key;
  }

  Future<void> _loadStartupState() async {
    await _loadSavedMode();
    await _loadPreferences();
    if (mounted) {
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
    await prefs.setInt('theme_seed_color', seedColor.value);
    await prefs.setBool('auto_play_enabled', autoPlay);

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
                            (c) => c.value == tempColor.value,
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

  bool _isExplicitlyPausedForRecording = false;

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
    String? audioPath,
    String? albumCover,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> history = prefs.getStringList('song_history') ?? [];

    final Map<String, dynamic> historyObj = {
      'song': songEntry,
      'audioPath': audioPath ?? '',
      'albumCover': albumCover ?? '',
    };

    history.insert(0, jsonEncode(historyObj));
    await prefs.setStringList('song_history', history);
  }

  Future<void> _playSingleDing() async {
    try {
      await _dingPlayer.stop();
      await _dingPlayer.play(AssetSource('ding.mp3'));
    } catch (e) {
      debugPrint('Error playing ding sound: $e');
    }
  }

  Future<void> _playErrorCue() async {
    // Keep failure feedback entirely local. The previous remote MP3 could fail
    // precisely when the network was already having trouble.
    try {
      await SystemSound.play(SystemSoundType.alert);
    } catch (_) {}
    try {
      await HapticFeedback.mediumImpact();
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
        return 7500;
      case EnvironmentMode.loud:
        return 8500;
      case EnvironmentMode.Outdoors:
        return 9000;
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

  bool _shouldOfferTopGuesses(List<_SongMatchCandidate> candidates) {
    if (_autoPlayEnabled || candidates.isEmpty) return false;
    final double? top = candidates.first.confidence;
    if (top == null) return false;

    if (top < _dynamicConfidenceThreshold) return true;

    if (candidates.length > 1) {
      final second = candidates[1].confidence;
      if (second != null && top < 0.92 && (top - second).abs() < 0.06) {
        return true;
      }
    }
    return false;
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
    return queuedPath;
  }

  Future<void> _checkPendingOfflineQueue() async {
    if (_offlineQueueProcessing || _isRecording || _isLoading) return;

    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) return;

    _offlineQueueProcessing = true;
    try {
      while (mounted && !_isRecording && !_isLoading) {
        final prefs = await SharedPreferences.getInstance();
        final List<String> queue =
            prefs.getStringList('pending_offline_songs') ?? [];
        if (queue.isEmpty) break;

        final String path = queue.first;
        if (!kIsWeb && !await File(path).exists()) {
          queue.removeAt(0);
          await prefs.setStringList('pending_offline_songs', queue);
          continue;
        }

        final online = await Connectivity().checkConnectivity();
        if (online.contains(ConnectivityResult.none)) break;

        final bool processed =
            await _sendAudioToBackend(path, isFromOfflineQueue: true);
        if (!processed) break;

        final freshPrefs = await SharedPreferences.getInstance();
        final List<String> freshQueue =
            freshPrefs.getStringList('pending_offline_songs') ?? [];
        freshQueue.remove(path);
        await freshPrefs.setStringList('pending_offline_songs', freshQueue);
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
    _isExplicitlyPausedForRecording = false;
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
      if (mounted) {
        setState(() {
          _isLoading = false;
          _customStatusText = '${t('error_stopping')}: $e';
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
    request.fields['vocal_isolation'] = 'true';
    request.fields['environment'] = _selectedMode.name;

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

      final streamedResponse =
          await request.send().timeout(const Duration(seconds: 25));
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
        if (mounted) {
          setState(() {
            _customStatusText = t('error_no_lyrics');
          });
        }
        unawaited(_playErrorCue());
        return true;
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
        final aScore = a.confidence;
        final bScore = b.confidence;
        if (aScore == null && bScore == null) return 0;
        if (aScore == null) return 1;
        if (bScore == null) return -1;
        return bScore.compareTo(aScore);
      });

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

      // Your requested behavior: ambiguity UI is NEVER allowed to interrupt
      // hands-free Auto Play. It is also skipped for background offline-queue
      // processing because nobody may be looking at the screen then.
      if (!isFromOfflineQueue && _shouldOfferTopGuesses(candidates)) {
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
          _customStatusText = '${t('connection_failed')}: $e';
        });
      }
      unawaited(_playErrorCue());
      return false;
    }
  }

  Future<void> _selectTopGuess(_SongMatchCandidate candidate) async {
    if (_autoPlayEnabled || _isLoading) return;
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
      allowAutoPlay: false,
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
  }) async {
    final String title = candidate.title;
    final String artist = candidate.artist == 'Unknown Artist'
        ? t('unknown_artist')
        : candidate.artist;

    if (mounted) {
      setState(() {
        _songTitle = title;
        _artist = artist;
        _spotifyUrl = candidate.spotifyUrl;
        _appleMusicUrl = candidate.appleMusicUrl;
        _albumArtUrl = candidate.coverUrl;
        _topGuesses = <_SongMatchCandidate>[];
        _statusTextKey = 'match_found';
        _customStatusText = null;
        _isLoading = false;
      });
    }

    final metadata = await fetchSongMetadata('$title $artist');
    final String? albumArt =
        (candidate.coverUrl != null && candidate.coverUrl!.isNotEmpty)
            ? candidate.coverUrl
            : metadata.artworkUrl;
    final String genre = candidate.genre != null && candidate.genre != 'other'
        ? candidate.genre!
        : (metadata.genre ?? 'other');
    final String emotion = _normalizeEmotion(candidate.emotion);

    if (mounted) {
      setState(() {
        _albumArtUrl = albumArt;
      });
    }

    await _saveToHistory(
      '$title - $artist',
      audioPath: audioPath,
      albumCover: albumArt,
    );

    await recordSessionToAnalytics(
      songTitle: title,
      artistName: artist,
      primaryEmotion: emotion,
      genre: genre,
      latitude: _sessionLocation?.latitude,
      longitude: _sessionLocation?.longitude,
    );

    if (isFromOfflineQueue) {
      unawaited(showQueuedSongFoundNotification(_selectedLanguage));
    }

    if (allowAutoPlay && _autoPlayEnabled) {
      if (_preferredMusicApp == 'apple_music' &&
          _appleMusicUrl != null &&
          _appleMusicUrl!.isNotEmpty) {
        unawaited(_openMusicUrl(_appleMusicUrl!));
      } else if (_spotifyUrl != null && _spotifyUrl!.isNotEmpty) {
        unawaited(_openSpotifyNative(_spotifyUrl!));
      }
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

    final int totalSongs = (prefs.getInt('analytics_total_songs') ?? 0) + 1;
    await prefs.setInt('analytics_total_songs', totalSongs);

    final int emotionCount =
        (prefs.getInt('analytics_emotion_$primaryEmotion') ?? 0) + 1;
    await prefs.setInt('analytics_emotion_$primaryEmotion', emotionCount);

    final String? artistJson = prefs.getString('analytics_artist_counts');
    Map<String, dynamic> artistMap = {};
    if (artistJson != null) {
      try {
        artistMap = jsonDecode(artistJson) as Map<String, dynamic>;
      } catch (_) {}
    }
    artistMap[artistName] = (artistMap[artistName] ?? 0) + 1;
    await prefs.setString('analytics_artist_counts', jsonEncode(artistMap));

    final String? genreJson = prefs.getString('analytics_genre_counts');
    Map<String, dynamic> genreMap = {};
    if (genreJson != null) {
      try {
        genreMap = jsonDecode(genreJson) as Map<String, dynamic>;
      } catch (_) {}
    }
    genreMap[genre] = (genreMap[genre] ?? 0) + 1;
    await prefs.setString('analytics_genre_counts', jsonEncode(genreMap));

    // A streak only needs one entry per calendar day. The old implementation
    // appended one timestamp per SONG, which could grow SharedPreferences
    // indefinitely for frequent users.
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

    if (latitude != null && longitude != null) {
      final List<String> memories =
          prefs.getStringList('acoustic_memories') ?? [];
      memories.add(jsonEncode({
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'title': songTitle,
        'lat': latitude,
        'lng': longitude,
        'timestamp': DateTime.now().toIso8601String(),
      }));
      await prefs.setStringList('acoustic_memories', memories);
    }
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

    final position = await getCurrentDeviceLocation();
    if (!mounted) return;
    _sessionLocation = position;

    if (position != null) {
      await prefs.setStringList('active_singing_locations', [
        jsonEncode({'lat': position.latitude, 'lng': position.longitude}),
      ]);
    } else {
      await prefs.remove('active_singing_locations');
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
          _customStatusText = '${t('connection_failed')}: $e';
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
                color: color.withOpacity(0.9),
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
                  backgroundColor: color.withOpacity(0.12),
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
                        onPressed: () => _showUserManualDialog(context),
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
                                  ? primaryColor.withOpacity(0.12)
                                  : theme.colorScheme.surfaceContainerHighest
                                      .withOpacity(isDarkMode ? 0.45 : 0.65),
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
                                      .withOpacity(_isRecording
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
                  if (!_autoPlayEnabled && _topGuesses.isNotEmpty) ...[
                    const SizedBox(height: 22),
                    _buildTopGuessesCard(),
                  ],
                  const SizedBox(height: 30),
                  if (_songTitle != null && _artist != null) ...[
                    Card(
                      elevation: 6,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
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

  void _showUserManualDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(Icons.menu_book, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text(t('User Manual')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t('got it')),
          ),
        ],
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

  @override
  void initState() {
    super.initState();
    _genreCounts = {
      'pop': 0,
      'rock': 0,
      'indie': 0,
      'jazz': 0,
    };
    _curatedPlaylistTitle = t('analyzing');
    _countdownText = t('calculating');
    _computeAnalytics();
  }

  Offset _latLngToMapOffset(double lat, double lng) {
    double dx = ((lng + 180) / 360).clamp(0.0, 1.0);
    double dy = ((90 - lat) / 180).clamp(0.0, 1.0);
    return Offset(dx, dy);
  }



  Future<void> _launchStreamingLink() async {
    final playlistData = _curatePlaylistByMajorityEmotion(_majorityEmotion);
    final targetUrl = playlistData['url'] ?? _streamingUrl;

    if (targetUrl.isEmpty) return;

    final uri = Uri.parse(targetUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _computeAnalytics() async {
    final prefs = await SharedPreferences.getInstance();

    _preferredApp = prefs.getString('preferred_music_app') ?? 'spotify';
    bool activeSinging = prefs.getBool('is_currently_singing') ?? false;

    List<String> rawCoordinates = prefs.getStringList('active_singing_locations') ?? [];
    List<Offset> calculatedOffsets = [];

    for (String rawCoord in rawCoordinates) {
      try {
        final data = jsonDecode(rawCoord);
        double lat = (data['lat'] as num).toDouble();
        double lng = (data['lng'] as num).toDouble();
        calculatedOffsets.add(_latLngToMapOffset(lat, lng));
      } catch (_) {}
    }

    // --- Permanent counters (survive "Clear History") ---
    Map<String, int> emotionMap = {'happy': 0, 'sad': 0, 'hype': 0, 'romantic': 0};
    for (String key in emotionMap.keys.toList()) {
      emotionMap[key] = prefs.getInt('analytics_emotion_$key') ?? 0;
    }

    Map<String, int> artistMap = {};
    final String? artistJson = prefs.getString('analytics_artist_counts');
    if (artistJson != null) {
      final decoded = jsonDecode(artistJson) as Map<String, dynamic>;
      decoded.forEach((key, value) => artistMap[key] = (value as num).toInt());
    }

    Map<String, int> rawGenreMap = {};
    final String? genreJson = prefs.getString('analytics_genre_counts');
    if (genreJson != null) {
      final decoded = jsonDecode(genreJson) as Map<String, dynamic>;
      decoded.forEach((key, value) => rawGenreMap[key] = (value as num).toInt());
    }
    final defaultFallbacks = ['pop', 'rock', 'indie', 'jazz'];
    for (String fallback in defaultFallbacks) {
      rawGenreMap.putIfAbsent(fallback, () => 0);
    }

    var sortedRawGenres = rawGenreMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    var top4Genres = sortedRawGenres.take(4);

    Map<String, int> top4GenreCounts = {};
    for (var entry in top4Genres) {
      top4GenreCounts[entry.key] = entry.value;
    }

    var sortedArtists = artistMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    List<String> topArtistsList = sortedArtists.map((e) => e.key).take(3).toList();

    String calculatedMajority = 'happy';
    if (emotionMap.values.any((v) => v > 0)) {
      var dominant = emotionMap.entries.reduce((a, b) => a.value > b.value ? a : b);
      if (dominant.value <= 1 && topArtistsList.isNotEmpty) {
        calculatedMajority = 'fallback';
      } else {
        calculatedMajority = dominant.key;
      }
    } else {
      calculatedMajority = 'fallback';
    }

    // Streak is computed from a permanent list of session dates, not from
    // song_history, so it doesn't reset when history is cleared.
    List<String> rawSessionDates = prefs.getStringList('analytics_session_dates') ?? [];
    List<DateTime> sessionDates = rawSessionDates
        .map((s) => DateTime.tryParse(s))
        .whereType<DateTime>()
        .toList();

    int calculatedStreak = _calculateStreak(sessionDates);

    setState(() {
      _singingStreak = calculatedStreak;
      _topArtists = topArtistsList;
      _emotionCounts = emotionMap;
      _genreCounts = top4GenreCounts;
      _isCurrentlySinging = activeSinging;
      _livePinLocations = calculatedOffsets;
      _majorityEmotion = calculatedMajority;
    });

    await _handleBiWeeklyPlaylistRotation(prefs);
  }

  Future<void> _handleBiWeeklyPlaylistRotation(SharedPreferences prefs) async {
    final int fourteenDaysInMs = 14 * 24 * 60 * 60 * 1000;
    int now = DateTime.now().millisecondsSinceEpoch;

    int? lastGeneratedTime = prefs.getInt('playlist_timestamp');
    String? savedPlaylist = prefs.getString('saved_curated_playlist');

    var freshPlaylistData = _curatePlaylistByMajorityEmotion(_majorityEmotion);

    String selectedTitle = freshPlaylistData['title']!;
    if (lastGeneratedTime == null || savedPlaylist == null || (now - lastGeneratedTime > fourteenDaysInMs)) {
      await prefs.setInt('playlist_timestamp', now);
      await prefs.setString('saved_curated_playlist', selectedTitle);
      lastGeneratedTime = now;
    } else {
      selectedTitle = savedPlaylist;
    }

    int timeLeft = fourteenDaysInMs - (now - lastGeneratedTime);
    int daysLeft = timeLeft ~/ (24 * 60 * 60 * 1000);
    int hoursLeft = (timeLeft % (24 * 60 * 60 * 1000)) ~/ (60 * 60 * 1000);

    setState(() {
      _curatedPlaylistTitle = selectedTitle;
      _streamingUrl = freshPlaylistData['url']!;
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

  Map<String, String> _curatePlaylistByMajorityEmotion(String emotion) {
  final normalizedEmotion = emotion.toLowerCase().trim();

  final Map<String, Map<String, String>> emotionPlaylists = {
    'sad': {
      'title': 'Nostaligic Mix',
      'query': 'Sad Indie',
    },
    'hype': {
      'title': 'Pump Up Mix',
      'query': 'Workout Hits',
    },
    'romantic': {
      'title': 'Romance Essentials',
      'query': 'Love Songs Essentials',
    },
    'happy': {
      'title': 'Feel-Good Mix',
      'query': 'Happy Hits',
    },
  };

  String title = emotionPlaylists[normalizedEmotion]?['title'] ?? 'Feel-Good Mix';
  String query = emotionPlaylists[normalizedEmotion]?['query'] ?? 'Happy Hits';

  // Handle fallback, balanced, empty, or unmapped mood states dynamically
  if (normalizedEmotion == 'balanced' ||
      normalizedEmotion.isEmpty ||
      normalizedEmotion == 'fallback' ||
      !emotionPlaylists.containsKey(normalizedEmotion)) {
    if (_topArtists.isNotEmpty) {
      final topArtistName = _topArtists.first.trim();
      title = "Best of $topArtistName Essentials Mix";
      query = "$topArtistName Essentials";
    }
  }

  final encodedQuery = Uri.encodeComponent(query);

  final url = (_preferredApp == 'apple_music')
      ? "https://music.apple.com/us/search?term=$encodedQuery"
      : "https://open.spotify.com/search/$encodedQuery/playlists";

  return {"title": title, "url": url};
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
                  color: Colors.grey.withOpacity(0.4),
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
                        themeColor.withOpacity(0.85),
                        const Color(0xFF121212),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: themeColor.withOpacity(0.5), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: themeColor.withOpacity(0.3),
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
                              children: _genreCounts.entries.take(3).map((genre) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 3.0),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: Text(
                                          t(genre.key),
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
                                        color: isDarkMode ? Colors.white70 : themeColor.withOpacity(0.75),
                                        colorBlendMode: BlendMode.modulate,
                                        errorBuilder: (context, error, stackTrace) => Container(
                                          color: isDarkMode ? Colors.grey.shade900 : Colors.blueGrey.shade100,
                                          child: Center(
                                            child: Icon(Icons.public, size: 60, color: themeColor.withOpacity(0.4)),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (_isCurrentlySinging && _livePinLocations.isNotEmpty)
                                    ..._livePinLocations.map((pinOffset) {
                                      return Align(
                                        alignment: FractionalOffset(
                                          pinOffset.dx,
                                          pinOffset.dy,
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.redAccent,
                                                borderRadius: BorderRadius.circular(8),
                                                boxShadow: const [
                                                  BoxShadow(
                                                    color: Colors.black38,
                                                    blurRadius: 4,
                                                    offset: Offset(0, 2),
                                                  )
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
                                            const Icon(Icons.location_on, color: Colors.redAccent, size: 28),
                                          ],
                                        ),
                                      );
                                    }),
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
                            color: Colors.black.withOpacity(0.5),
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
          color: Colors.grey.withOpacity(0.3),
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
                        child: _buildThemedCard(
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
                        child: _buildThemedCard(
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
                        child: _buildThemedCard(
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
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    _curatedPlaylistTitle,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 15,
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
                  child: _buildThemedCard(
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
                                      color: isDarkMode ? Colors.white70 : themeColor.withOpacity(0.75),
                                      colorBlendMode: BlendMode.modulate,
                                      errorBuilder: (context, error, stackTrace) => Container(
                                        color: isDarkMode ? Colors.grey.shade900 : Colors.blueGrey.shade100,
                                        child: Center(
                                          child: Icon(Icons.public, size: 80, color: themeColor.withOpacity(0.4)),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                if (_isCurrentlySinging && _livePinLocations.isNotEmpty)
                                  ..._livePinLocations.map((pinOffset) {
                                    return Align(
                                      alignment: FractionalOffset(
                                        pinOffset.dx,
                                        pinOffset.dy,
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.redAccent,
                                              borderRadius: BorderRadius.circular(8),
                                              boxShadow: const [
                                                BoxShadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 2))
                                              ],
                                            ),
                                            child: const Text(
                                              "LIVE",
                                              style: TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                          const Icon(Icons.location_on, color: Colors.redAccent, size: 32),
                                        ],
                                      ),
                                    );
                                  }),
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
                _buildThemedCard(
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
                                  t(sortedGenres[i].key),
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
                              backgroundColor: Colors.grey.withOpacity(0.15),
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
                _buildThemedCard(
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
        border: Border.all(color: themeColor.withOpacity(0.55), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: themeColor.withOpacity(0.05),
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
  Future<bool> createPlaylistFromHistory(
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

      if (trackUris.isEmpty) return false;

      // Spotify's current API creates a playlist for the authenticated user at
      // /me/playlists; the old /users/{id}/playlists endpoint was removed.
      final playlistRes = await http.post(
        Uri.parse('https://api.spotify.com/v1/me/playlists'),
        headers: headers,
        body: jsonEncode({
          'name': t('playlist_name'),
          'description': t('playlist_desc'),
          'public': true,
        }),
      ).timeout(const Duration(seconds: 15));

      if (playlistRes.statusCode != 201) return false;
      final playlistId = jsonDecode(playlistRes.body)['id']?.toString();
      if (playlistId == null || playlistId.isEmpty) return false;

      // Spotify now calls these "items" rather than the deprecated /tracks
      // endpoint. Add in chunks of 100, the playlist API's usual request cap.
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
          return false;
        }
      }

      return true;
    } catch (e) {
      debugPrint('Spotify playlist creation failed: $e');
      return false;
    }
  }
}
// Updated _exportToSpotify method inside _HistoryPageState

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
  if (str.startsWith('{')) {
    try {
      final parsed = jsonDecode(str);
      str = parsed['song']?.toString() ?? str;
    } catch (_) {}
  }
  if (str.contains(' - ')) {
    return str.split(' - ').first.trim();
  }
  return str;
}

String _parseArtist(dynamic rawItem) {
  String str = rawItem.toString();
  if (str.startsWith('{')) {
    try {
      final parsed = jsonDecode(str);
      str = parsed['song']?.toString() ?? str;
    } catch (_) {}
  }
  if (str.contains(' - ')) {
    final parts = str.split(' - ');
    if (parts.length > 1) {
      return parts.sublist(1).join(' - ').trim();
    }
  }
  return '';
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

  Future<void> _exportToSpotify() async {
    final selectedTitles = _selectedItems
        .map((item) {
          final title = _parseSongTitle(item);
          final artist = _parseArtist(item);
          return artist.isEmpty ? title : '$title $artist';
        })
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

    final success = await spotifyService.createPlaylistFromHistory(token, selectedTitles, t);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? t('playlist_success') : t('playlist_error'),
          ),
        ),
      );
    }
  }

  Future<void> _exportToAppleMusic() async {
    final selectedTitles = _selectedItems
        .map((item) {
          final title = _parseSongTitle(item);
          final artist = _parseArtist(item);
          return artist.isEmpty ? title : '$title $artist';
        })
        .toList();

    if (selectedTitles.isEmpty) return;

    final primaryTitle = selectedTitles.first;
    final encodedQuery = Uri.encodeComponent(primaryTitle);
    final Uri appleUrl = Uri.parse("https://music.apple.com/us/search?term=$encodedQuery");

    if (await canLaunchUrl(appleUrl)) {
      await launchUrl(appleUrl, mode: LaunchMode.externalApplication);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${t('opening_apple_search')} "$primaryTitle"')),
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
        subtitle: Text(
          t('tap_to_play_preferred'),
          style: const TextStyle(fontSize: 12, color: Colors.grey),
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
      'in the style of',
      'instrumental version',
      'sound alike',
      'sound-alike',
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
            themeColor.withOpacity(0.85),
            const Color(0xFF121212),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: themeColor.withOpacity(0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: themeColor.withOpacity(0.3),
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
                color: Colors.black.withOpacity(0.5),
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
                    color: Colors.grey.withOpacity(0.4),
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