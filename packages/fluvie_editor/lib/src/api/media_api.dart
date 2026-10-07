/// Media, audio, colour, and effect authoring API.
library;

export '../audio/audio_ducking.dart' show duckingAutomation;
export '../audio/audio_meter.dart' show AudioMeterLevel, decibelsToGain, gainToDecibels, meterTrack;
export '../audio/audio_monitor_controller.dart' show AudioMonitorController;
export '../audio/audio_preview_mix.dart' show AudioPreviewTrack, renderAudioPreviewWav;
export '../audio/audio_track_view.dart' show AudioTrackView, audioTrackViews;
export '../audio/audio_workspace_panel.dart' show AudioWorkspacePanel;
export '../audio/timeline_audio_envelopes.dart' show timelineAudioEnvelopes;
export '../colour/colour_looks.dart';
export '../colour/colour_panel.dart';
export '../colour/colour_scopes.dart';
export '../effects/effect_browser.dart' show EffectBrowser;
export '../effects/effect_catalog.dart' show EffectCatalogEntry, effectCatalog, searchEffectCatalog;
export '../effects/effect_drag_data.dart' show EffectDragData;
export '../effects/effect_stopwatch.dart'
    show elementWindowFramesOf, stopwatchLiteralFor, stopwatchRampFor;
export '../effects/effects_panel.dart' show EffectsPanel;
export '../effects/effects_section.dart' show EffectsSection;
export '../media/media_bin.dart' show MediaBinQuery, MediaBinSort, mediaBinFolders, mediaBinListing;
export '../media/media_bin_panel.dart' show MediaBinPanel, MediaBinRow;
export '../media/media_import.dart'
    show documentBundleValues, referencedBundleValues, storeEntryFor;
export '../media/media_store_entry.dart' show MediaStoreEntry, MediaStoreKind;
export '../media/source_media_preview.dart' show SourceMediaPreview;
export '../media/source_monitor.dart' show SourceMonitor, SourceMonitorPlacement;
