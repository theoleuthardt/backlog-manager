import 'package:backlog_manager/design/shelf_text.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/design/widgets/buttons.dart';
import 'package:backlog_manager/design/widgets/chips.dart';
import 'package:backlog_manager/design/widgets/cover.dart';
import 'package:backlog_manager/design/widgets/fields.dart';
import 'package:backlog_manager/design/widgets/menu.dart';
import 'package:backlog_manager/design/widgets/progress.dart';
import 'package:backlog_manager/design/widgets/segmented.dart';
import 'package:backlog_manager/design/widgets/select.dart';
import 'package:backlog_manager/design/widgets/sheet.dart';
import 'package:backlog_manager/design/widgets/stepper.dart';
import 'package:backlog_manager/design/widgets/table.dart';
import 'package:backlog_manager/design/widgets/tabs.dart';
import 'package:backlog_manager/design/widgets/toast.dart';
import 'package:backlog_manager/design/widgets/toggles.dart';
import 'package:backlog_manager/features/common/status_select.dart';
import 'package:flutter/material.dart';

class _Game {
  const _Game(this.title, this.hours);

  final String title;
  final int hours;
}

/// Every component of the UI kit with its states, to look at while building.
class GalleryPage extends StatefulWidget {
  const GalleryPage({super.key});

  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
  int _segment = 1;
  int _tab = 0;
  bool _switch = true;
  bool? _check = true;
  int _interest = 6;
  int _stars = 7;
  String? _sort = 'status';
  String _status = 'In Progress';
  final Set<String> _selected = {'Celeste'};

  static const _games = [
    _Game('Hades', 41),
    _Game('Celeste', 8),
    _Game('Outer Wilds', 22),
  ];

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).extension<ShelfTextStyles>()!;

    return SingleChildScrollView(
      key: const Key('page-gallery'),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Components', style: text.page),
          const SizedBox(height: 20),
          _section('Buttons', [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                ShelfButton(
                  label: 'Primary',
                  kind: ShelfButtonKind.primary,
                  onPressed: () {},
                ),
                ShelfButton(label: 'Secondary', onPressed: () {}),
                ShelfButton(
                  label: 'Quiet',
                  kind: ShelfButtonKind.quiet,
                  onPressed: () {},
                ),
                ShelfButton(
                  label: 'Delete',
                  kind: ShelfButtonKind.danger,
                  onPressed: () {},
                ),
                ShelfButton(
                  label: 'With icon',
                  icon: Icons.add,
                  onPressed: () {},
                ),
                const ShelfButton(label: 'Disabled', onPressed: null),
                ShelfIconButton(
                  icon: Icons.close,
                  tooltip: 'Close',
                  onPressed: () {},
                ),
              ],
            ),
          ]),
          _section('Chips', [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                const ShelfChip(label: 'Neutral'),
                const ShelfChip(label: 'Active', kind: ShelfChipKind.active),
                const ShelfChip(label: 'Accent', kind: ShelfChipKind.accent),
                const ShelfChip(label: 'Info', kind: ShelfChipKind.info),
                const ShelfChip(label: 'Ok', kind: ShelfChipKind.ok),
                ShelfChip(label: 'Genre: RPG', onRemove: () {}),
                const ShelfChip(label: 'Add filter', kind: ShelfChipKind.add),
              ],
            ),
          ]),
          _section('Segmented control and tabs', [
            ShelfSegmented<int>(
              value: _segment,
              onChanged: (value) => setState(() => _segment = value),
              segments: const [
                ShelfSegment(value: 0, label: 'Library'),
                ShelfSegment(value: 1, label: 'Wishlist'),
                ShelfSegment(value: 2, label: 'Playtimes'),
              ],
            ),
            const SizedBox(height: 16),
            ShelfTabs(
              labels: const ['Overview', 'Progress', 'Review', 'Trailer'],
              index: _tab,
              onChanged: (value) => setState(() => _tab = value),
            ),
          ]),
          _section('Fields and form group', [
            const SizedBox(
              width: 360,
              child: ShelfField(
                label: 'Title',
                hintText: 'Name of the game',
                hint: 'Shown on the cover',
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: 360,
              child: ShelfSelect<String>(
                label: 'Default sort',
                value: _sort,
                onChanged: (value) => setState(() => _sort = value),
                options: const [
                  ShelfOption(value: 'status', label: 'Status'),
                  ShelfOption(value: 'genre', label: 'Genre'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: 360,
              child: StatusSelect(
                value: _status,
                onChanged: (value) => setState(() => _status = value),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 560,
              child: ShelfFormGroup(
                title: 'General',
                description: 'How the app sorts your games',
                rows: [
                  ShelfFormRow(
                    label: 'Owned only',
                    description: 'Hide games you do not own',
                    control: ShelfSwitch(
                      value: _switch,
                      onChanged: (value) => setState(() => _switch = value),
                    ),
                  ),
                  const ShelfFormRow(
                    label: 'Language',
                    control: Text('English'),
                  ),
                ],
              ),
            ),
          ]),
          _section('Switch, checkbox, progress, interest and stars', [
            Row(
              children: [
                ShelfSwitch(
                  value: _switch,
                  onChanged: (value) => setState(() => _switch = value),
                ),
                const SizedBox(width: 16),
                ShelfCheckbox(
                  value: _check,
                  onChanged: (value) => setState(() => _check = value),
                ),
                const SizedBox(width: 8),
                ShelfCheckbox(value: null, onChanged: (_) {}),
              ],
            ),
            const SizedBox(height: 16),
            const SizedBox(width: 360, child: ShelfProgressBar(value: 0.62)),
            const SizedBox(height: 16),
            SizedBox(
              width: 360,
              child: InterestSegments(
                value: _interest,
                onChanged: (value) => setState(() => _interest = value),
              ),
            ),
            const SizedBox(height: 12),
            StarRating(
              value: _stars,
              onChanged: (value) => setState(() => _stars = value),
            ),
          ]),
          _section('Covers', [
            Wrap(
              spacing: 16,
              runSpacing: 22,
              children: const [
                SizedBox(width: 130, child: ShelfCover(title: 'Hades')),
                SizedBox(
                  width: 130,
                  child: ShelfCover(
                    title: 'Celeste',
                    progress: 0.4,
                    meta: '41 of 60 h',
                  ),
                ),
                SizedBox(
                  width: 130,
                  child: ShelfCover(title: 'Disco Elysium', selected: true),
                ),
                SizedBox(
                  width: 130,
                  child: ShelfCover(
                    title: 'Outer Wilds',
                    selectionMode: true,
                    selected: true,
                  ),
                ),
              ],
            ),
          ]),
          _section('Data table', [
            SizedBox(
              width: 640,
              child: ShelfDataTable<_Game>(
                columns: [
                  ShelfColumn(
                    header: 'Title',
                    flex: 3,
                    cell: (context, game) => Text(game.title),
                  ),
                  ShelfColumn(
                    header: 'Hours',
                    cell: (context, game) => Text('${game.hours} h'),
                  ),
                ],
                rows: _games,
                onRowTap: (_) {},
                isSelected: (game) => _selected.contains(game.title),
                onSelectionChanged: (game, selected) => setState(() {
                  selected
                      ? _selected.add(game.title)
                      : _selected.remove(game.title);
                }),
                onSelectAll: (all) => setState(() {
                  _selected
                    ..clear()
                    ..addAll(all ? _games.map((game) => game.title) : const []);
                }),
              ),
            ),
          ]),
          _section('Menu, sheet and toast', [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                ShelfMenuAnchor(
                  entries: [
                    ShelfMenuItem(
                      label: 'Open details',
                      shortcut: '↵',
                      onSelected: () {},
                    ),
                    ShelfMenuItem(label: 'Select', onSelected: () {}),
                    ShelfMenuItem(
                      label: 'Move to status',
                      submenu: [
                        ShelfMenuItem(label: 'Completed', onSelected: () {}),
                      ],
                    ),
                    const ShelfMenuDivider(),
                    ShelfMenuItem(
                      label: 'Delete',
                      danger: true,
                      onSelected: () {},
                    ),
                  ],
                  builder: (context, controller) => ShelfButton(
                    label: 'Open a menu',
                    onPressed: () => controller.isOpen
                        ? controller.close()
                        : controller.open(),
                  ),
                ),
                ShelfButton(
                  label: 'Open a sheet',
                  onPressed: () => showShelfSheet<void>(
                    context,
                    builder: (context) => ShelfSheet(
                      title: 'Add a game',
                      description: 'Search IGDB for the game',
                      footer: ShelfSheetFooter(
                        onCancel: () => Navigator.of(context).maybePop(),
                        primary: ShelfButton(
                          label: 'Continue',
                          kind: ShelfButtonKind.primary,
                          onPressed: () {},
                        ),
                      ),
                      child: const Text('Results'),
                    ),
                  ),
                ),
                ShelfButton(
                  label: 'Show a toast',
                  onPressed: () => showShelfToast(
                    context,
                    'Moved to Completed',
                    actionLabel: 'Undo',
                    onAction: () {},
                  ),
                ),
              ],
            ),
          ]),
          _section('Stepper', [
            const SizedBox(
              width: 240,
              child: ShelfStepper(
                steps: ['Theme', 'Sort', 'Steam', 'Done'],
                current: 2,
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final text = Theme.of(context).extension<ShelfTextStyles>()!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: text.sidebarLabel.copyWith(color: tokens.faint),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}
