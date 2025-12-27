export class CreateRoomDto {
  userName: string;
  roomTitle?: string; // 방 제목 (선택)
  description?: string; // 방 설명 (선택)
  maxParticipants?: number; // 최대 인원 (기본값: 10)
}

export class RoomMetadata {
  roomId: string;
  roomTitle: string;
  description: string;
  maxParticipants: number;
  createdBy: string;
  createdAt: Date;
}
