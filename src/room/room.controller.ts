import { Controller, Post, Body, Get, Param } from "@nestjs/common";
import { RoomService } from "./room.service";
import { randomUUID } from "crypto";
import { CreateRoomDto, RoomMetadata } from "./dto/create-room.dto";

interface TokenRequest {
  roomName: string;
  userName: string;
}

interface TokenResponse {
  token: string;
  url: string;
}

@Controller("api")
export class RoomController {
  constructor(private readonly roomService: RoomService) {}

  /**
   * Token 발급 API
   * POST /api/token
   */
  @Post("token")
  async getToken(@Body() body: TokenRequest): Promise<TokenResponse> {
    const { roomName, userName } = body;

    if (!roomName || !userName) {
      throw new Error("roomName and userName are required");
    }

    // Token 생성
    const token = await this.roomService.createToken(roomName, userName);

    return {
      token,
      url: process.env.LIVEKIT_URL || "ws://localhost:7880",
    };
  }

  /**
   * 상태 확인 API
   * GET /api/health
   */
  @Get("health")
  health() {
    return {
      status: "ok",
      timestamp: new Date().toISOString(),
    };
  }

  /**
   * 방 생성 API
   * POST /api/room/create
   * 방 제목, 설명, 최대 인원 설정 가능
   */
  @Post("room/create")
  async createRoom(@Body() dto: CreateRoomDto) {
    if (!dto.userName) {
      throw new Error("userName is required");
    }

    const roomId = `room-${randomUUID()}`;
    const frontendUrl = process.env.FRONTEND_URL || "http://localhost:3000";
    const maxParticipants = dto.maxParticipants || 10;

    // 1. LiveKit 서버에 실제 방 생성
    await this.roomService.createRoomOnLiveKit(roomId, maxParticipants);

    // 2. 방 메타데이터 저장
    const metadata: RoomMetadata = {
      roomId,
      roomTitle: dto.roomTitle || `${dto.userName}의 방`,
      description: dto.description || "",
      maxParticipants,
      createdBy: dto.userName,
      createdAt: new Date(),
    };
    this.roomService.saveRoomMetadata(metadata);

    // 3. 입장 토큰 생성
    const token = await this.roomService.createToken(roomId, dto.userName);

    return {
      roomId,
      roomUrl: `${frontendUrl}/room/${roomId}`,
      roomTitle: metadata.roomTitle,
      description: metadata.description,
      maxParticipants,
      userName: dto.userName,
      token,
      livekitUrl: process.env.LIVEKIT_URL || "ws://localhost:7880",
    };
  }

  /**
   * 특정 방 정보 조회
   * GET /api/room/:roomId
   */
  @Get("room/:roomId")
  getRoomInfo(@Param("roomId") roomId: string) {
    const metadata = this.roomService.getRoomMetadata(roomId);

    if (!metadata) {
      throw new Error("Room not found");
    }

    return metadata;
  }

  /**
   * 모든 방 목록 조회
   * GET /api/rooms
   */
  @Get("rooms")
  getAllRooms() {
    return {
      rooms: this.roomService.getAllRooms(),
      total: this.roomService.getAllRooms().length,
    };
  }
}
