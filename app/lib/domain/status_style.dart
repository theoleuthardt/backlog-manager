const _statusColors = {
  'Not Started': '#94a3b8',
  'In Progress': '#38bdf8',
  'Completed': '#4ade80',
  'On Hold': '#fbbf24',
  'Dropped': '#f87171',
};

const _customStatusColor = '#c084fc';

/// Hex colour of a status; every custom status shares one colour.
String statusColor(String status) =>
    _statusColors[status] ?? _customStatusColor;
