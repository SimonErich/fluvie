part of 'media_bin_panel.dart';

final class _MediaBinPanelState extends State<MediaBinPanel> {
  final TextEditingController _search = TextEditingController();
  final TextEditingController _folder = TextEditingController();
  MediaBinQuery _query = const MediaBinQuery();
  String? _selectedId;

  @override
  void dispose() {
    _search.dispose();
    _folder.dispose();
    super.dispose();
  }

  /// The selected entry, re-read from the store every build so an edit
  /// elsewhere is what the monitor shows.
  MediaStoreEntry? get _selected {
    final id = _selectedId;
    if (id == null) return null;
    for (final entry in widget.entries) {
      if (entry.id == id) return entry;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final listing = mediaBinListing(widget.entries, _query);
    final folders = mediaBinFolders(widget.entries);
    final selected = _selected;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(folders),
        // The list and the monitor share the height rather than the list
        // taking all of it: an Expanded list leaves the monitor nothing, and
        // the monitor is the reason the bin is worth opening.
        Expanded(
          flex: 3,
          child: listing.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: OiLabel.small(
                      widget.entries.isEmpty
                          ? 'Import a file to start building the deck.'
                          : 'Nothing here matches that.',
                      color: colors.textMuted,
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: listing.length,
                  itemBuilder: (context, index) {
                    final entry = listing[index];
                    final row = MediaBinRow(
                      entry: entry,
                      selected: entry.id == _selectedId,
                      onTap: () => setState(() {
                        _selectedId = entry.id;
                        _folder.text = entry.folder ?? '';
                      }),
                    );
                    final range = entry.markedRange;
                    if (range == null && entry.kind != MediaStoreKind.image) return row;
                    return Draggable<SourceMonitorPlacement>(
                      data: (entry: entry, start: range?.start ?? 0, end: range?.end ?? 0),
                      feedback: SizedBox(width: 220, child: row),
                      child: row,
                    );
                  },
                ),
        ),
        if (selected != null)
          Flexible(
            flex: 2,
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OiTextInput(
                      key: ValueKey('folder-${selected.id}'),
                      label: 'Folder',
                      controller: _folder,
                      onSubmitted: (value) => widget.onEntryChanged(
                        selected.copyWith(folder: value.trim(), clearFolder: value.trim().isEmpty),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SourceMonitor(
                      entry: selected,
                      onMarked: widget.onEntryChanged,
                      onPlace: widget.onPlace,
                      previewBuilder: widget.previewBuilder,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _header(List<String> folders) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: OiTextInput(
                  controller: _search,
                  placeholder: 'Search media',
                  onChanged: (text) => setState(() => _query = _query.copyWith(search: text)),
                ),
              ),
              if (widget.onImport != null) ...[
                const SizedBox(width: 4),
                OiButton.secondary(label: 'Import media', onTap: widget.onImport),
              ],
            ],
          ),
          if (folders.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                _FolderChip(
                  label: 'All',
                  selected: _query.folder == null,
                  onTap: () => setState(() => _query = _query.copyWith(clearFolder: true)),
                ),
                for (final folder in folders)
                  _FolderChip(
                    label: folder,
                    selected: _query.folder == folder,
                    onTap: () => setState(() => _query = _query.copyWith(folder: folder)),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
