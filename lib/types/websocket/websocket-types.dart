// OpCodes

enum OpCode {
  dispatch(0),
  heartbeat(1),
  identify(2),
  presenceUpdate(3),
  focusChange(4),
  heartbeatAck(11),
  ready(12),
  invalidSession(13),
  typingStart(20),
  typingStop(21),
  messageCreate(22),
  messageEdit(23),
  messageDelete(24),
  messageAck(25);

  final int code;
  const OpCode(this.code);
}

// event types for dispatch

enum EventType {
  channelMessageCreate,
  channelMessageUpdate,
  channelMessageDelete,
  dmMessageCreate,
  dmMessageUpdate,
  dmMessageDelete,
  channelMessageNotify,
  dmMessageNotify,
  typingStart,
  typingStop,
  presenceUpdate,
  serverUpdate,
  serverMemberAdd,
  serverMemberRemove,
  serverMemberUpdate,
  channelCreate,
  channelUpdate,
  channelDelete,
  dmCreate,
  dmParticipantAdd,
  dmParticipantLeft,
  userUpdate,
  friendRequestCreate,
  friendRequestAccepted,
  friendRemove,
  messageAck,
}

String stringToEventType(EventType type) {
  switch (type) {
    case EventType.channelMessageCreate:
      return "CHANNEL_MESSAGE_CREATE";
    case EventType.channelMessageUpdate:
      return "CHANNEL_MESSAGE_UPDATE";
    case EventType.channelMessageDelete:
      return "CHANNEL_MESSAGE_DELETE";
    case EventType.dmMessageCreate:
      return "DM_MESSAGE_CREATE";
    case EventType.dmMessageUpdate:
      return "DM_MESSAGE_UPDATE";
    case EventType.dmMessageDelete:
      return "DM_MESSAGE_DELETE";
    case EventType.channelMessageNotify:
      return "CHANNEL_MESSAGE_NOTIFY";
    case EventType.dmMessageNotify:
      return "DM_MESSAGE_NOTIFY";
    case EventType.typingStart:
      return "TYPING_START";
    case EventType.typingStop:
      return "TYPING_STOP";
    case EventType.presenceUpdate:
      return "PRESENCE_UPDATE";
    case EventType.serverUpdate:
      return "SERVER_UPDATE";
    case EventType.serverMemberAdd:
      return "SERVER_MEMBER_ADD";
    case EventType.serverMemberRemove:
      return "SERVER_MEMBER_REMOVE";
    case EventType.serverMemberUpdate:
      return "SERVER_MEMBER_UPDATE";
    case EventType.channelCreate:
      return "CHANNEL_CREATE";
    case EventType.channelUpdate:
      return "CHANNEL_UPDATE";
    case EventType.channelDelete:
      return "CHANNEL_DELETE";
    case EventType.dmCreate:
      return "DM_CREATE";
    case EventType.dmParticipantAdd:
      return "DM_PARTICIPANT_ADD";
    case EventType.dmParticipantLeft:
      return "DM_PARTICIPANT_LEFT";
    case EventType.userUpdate:
      return "USER_UPDATE";
    case EventType.friendRequestCreate:
      return "FRIEND_REQUEST_CREATE";
    case EventType.friendRequestAccepted:
      return "FRIEND_REQUEST_ACCEPTED";
    case EventType.friendRemove:
      return "FRIEND_REMOVE";
    case EventType.messageAck:
      return "MESSAGE_ACK";
  }
}

final _eventTypeMap = <String, EventType>{
  'CHANNEL_MESSAGE_CREATE': EventType.channelMessageCreate,
  'CHANNEL_MESSAGE_UPDATE': EventType.channelMessageUpdate,
  'CHANNEL_MESSAGE_DELETE': EventType.channelMessageDelete,
  'DM_MESSAGE_CREATE': EventType.dmMessageCreate,
  'DM_MESSAGE_UPDATE': EventType.dmMessageUpdate,
  'DM_MESSAGE_DELETE': EventType.dmMessageDelete,
  'CHANNEL_MESSAGE_NOTIFY': EventType.channelMessageNotify,
  'DM_MESSAGE_NOTIFY': EventType.dmMessageNotify,
  'TYPING_START': EventType.typingStart,
  'TYPING_STOP': EventType.typingStop,
  'PRESENCE_UPDATE': EventType.presenceUpdate,
  'SERVER_UPDATE': EventType.serverUpdate,
  'SERVER_MEMBER_ADD': EventType.serverMemberAdd,
  'SERVER_MEMBER_REMOVE': EventType.serverMemberRemove,
  'SERVER_MEMBER_UPDATE': EventType.serverMemberUpdate,
  'CHANNEL_CREATE': EventType.channelCreate,
  'CHANNEL_UPDATE': EventType.channelUpdate,
  'CHANNEL_DELETE': EventType.channelDelete,
  'DM_CREATE': EventType.dmCreate,
  'DM_PARTICIPANT_ADD': EventType.dmParticipantAdd,
  'DM_PARTICIPANT_LEFT': EventType.dmParticipantLeft,
  'USER_UPDATE': EventType.userUpdate,
  'FRIEND_REQUEST_CREATE': EventType.friendRequestCreate,
  'FRIEND_REQUEST_ACCEPTED': EventType.friendRequestAccepted,
  'FRIEND_REMOVE': EventType.friendRemove,
  'MESSAGE_ACK': EventType.messageAck,
};

EventType eventTypeFromString(String str) {
  final type = _eventTypeMap[str];
  if (type == null) throw Exception('Unknown event type: $str');
  return type;
}
