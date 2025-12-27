import { Injectable } from "@nestjs/common";
import { AccessToken, RoomServiceClient } from "livekit-server-sdk";
import { RoomMetadata } from "./dto/create-room.dto";

@Injectable()
export class RoomService {
  private roomClient: RoomServiceClient;
  private roomMetadata: Map<string, RoomMetadata> = new Map(); // In-memory storage

  constructor() {
    const livekitUrl = process.env.LIVEKIT_URL || "ws://localhost:7880";
    const apiKey = process.env.LIVEKIT_API_KEY;
    const apiSecret = process.env.LIVEKIT_API_SECRET;

    if (!apiKey || !apiSecret) {
      console.warn("LiveKit credentials not configured");
    }

    this.roomClient = new RoomServiceClient(livekitUrl, apiKey, apiSecret);
  }
  /**
   * LiveKit 서버에 방 생성
   * @param roomName 방 이름
   * @param maxParticipants 최대 인원 (기본값: 10)
   * @returns 생성된 방 정보
   */
  async createRoomOnLiveKit(
    roomName: string,
    maxParticipants: number = 10
  ) {
    try {
      const room = await this.roomClient.createRoom({
        name: roomName,
        emptyTimeout: 300, // 5분 동안 비어있으면 자동 삭제
        maxParticipants,
      });

      console.log("Room created on LiveKit:", {
        name: room.name,
        sid: room.sid,
        maxParticipants: room.maxParticipants,
      });

      return room;
    } catch (error) {
      console.error("Failed to create room on LiveKit:", error);
      throw new Error(`Failed to create room: ${error.message}`);
    }
  }

  /**
   * 방 메타데이터 저장
   */
  saveRoomMetadata(metadata: RoomMetadata) {
    this.roomMetadata.set(metadata.roomId, metadata);
    console.log(`Room metadata saved: ${metadata.roomId}`);
  }

  /**
   * 방 메타데이터 조회
   */
  getRoomMetadata(roomId: string): RoomMetadata | undefined {
    return this.roomMetadata.get(roomId);
  }

  /**
   * 모든 방 목록 조회
   */
  getAllRooms(): RoomMetadata[] {
    return Array.from(this.roomMetadata.values());
  }

  /**
   * LiveKit Token 생성
   * @param roomName 방 이름
   * @param userName 사용자 이름
   * @returns JWT Token
   */
  async createToken(roomName: string, userName: string): Promise<string> {
    const apiKey = process.env.LIVEKIT_API_KEY;
    const apiSecret = process.env.LIVEKIT_API_SECRET;

    console.log("Creating token:", {
      roomName,
      userName,
      apiKey,
      hasSecret: !!apiSecret,
    });

    if (!apiKey || !apiSecret) {
      console.error("Missing API credentials!");
      throw new Error("LiveKit API Key or Secret not configured");
    }

    // AccessToken 생성
    const token = new AccessToken(apiKey, apiSecret, {
      identity: userName,
    });

    // 방 접근 권한 부여
    token.addGrant({
      roomJoin: true,
      room: roomName,
      canPublish: true, // 영상/음성 전송 가능
      canSubscribe: true, // 다른 사람 영상/음성 받기 가능
      canPublishData: true, // 데이터 전송 가능
    });

    // JWT 문자열로 반환
    const jwt = await token.toJwt();
    console.log("Token created:", jwt.substring(0, 50) + "...");
    return jwt;
  }
}
