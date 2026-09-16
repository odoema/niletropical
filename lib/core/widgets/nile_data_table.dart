/// Simple responsive data table for admin lists
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class NileDataColumn {
  const NileDataColumn({required this.label, this.flex = 1});
  final String label;
  final int flex;
}

class NileDataRow {
  const NileDataRow({required this.cells, this.onTap});
  final List<Widget> cells;
  final VoidCallback? onTap;
}

class NileDataTable extends StatelessWidget {
  const NileDataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.emptyMessage = 'No data',
  });

  final List<NileDataColumn> columns;
  final List<NileDataRow> rows;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(NileSpacing.xl),
        child: Center(child: Text(emptyMessage, style: NileTypography.bodyMedium)),
      );
    }

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: NileSpacing.md,
            vertical: NileSpacing.sm,
          ),
          decoration: const BoxDecoration(
            color: NileColors.surfaceVariant,
            border: Border(bottom: BorderSide(color: NileColors.border)),
          ),
          child: Row(
            children: [
              for (final col in columns)
                Expanded(
                  flex: col.flex,
                  child: Text(
                    col.label,
                    style: NileTypography.labelMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: NileColors.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
        ),
        // Rows
        ...rows.map((row) {
          return Material(
            color: NileColors.surface,
            child: InkWell(
              onTap: row.onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: NileSpacing.md,
                  vertical: NileSpacing.sm + 4,
                ),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: NileColors.divider)),
                ),
                child: Row(
                  children: [
                    for (var i = 0; i < columns.length; i++)
                      Expanded(
                        flex: columns[i].flex,
                        child: i < row.cells.length
                            ? row.cells[i]
                            : const SizedBox.shrink(),
                      ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}
