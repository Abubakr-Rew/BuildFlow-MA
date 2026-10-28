/// Kind of a chat.
enum ChatType {
  /// Two people of one company, created on demand.
  direct,

  /// The project team: directors, foremen and workers of the project.
  project;

  bool get isDirect => this == ChatType.direct;
  bool get isProject => this == ChatType.project;
}

/// What a message carries. Stage 1 renders [text] and [system]; the rest
/// come with later stages and show as «unsupported» until then.
enum MessageKind {
  text,

  /// Stage 2: photos in `Message.attachments`.
  photo,

  /// Stage 3: a voice note in `Message.attachments`.
  voice,

  /// Stage 4: a report card, `Message.reportId`.
  report,

  /// Written by the server: `Message.systemEvent` about
  /// `Message.subjectUserId`. The client words it.
  system;

  /// Whether this app version can render the kind.
  bool get isSupported => this == MessageKind.text || this == MessageKind.system;
}

/// Delivery state of the user's own message. The server only reports
/// [sent] and [read]; [sending] and [failed] exist on the client.
enum MessageStatus {
  sending,
  sent,

  /// Read by at least one other participant.
  read,
  failed;

  bool get isPending => this == MessageStatus.sending;
  bool get isFailed => this == MessageStatus.failed;
}

/// What a system message reports.
enum ChatSystemEvent {
  /// The subject joined the project team, and so the chat.
  memberAdded,

  /// The subject left the project team or the company.
  memberRemoved,
}
