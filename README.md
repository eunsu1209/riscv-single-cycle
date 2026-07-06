# riscv-single-cycle
RV32I 기반 Single-Cycle RISC-V 프로세서 Verilog 설계·검증
RV32I 명령어 집합을 기반으로 Single-Cycle RISC-V 프로세서를 Verilog로 설계하고, 명령어 타입별 파형 검증과 어셈블리 프로그램 실행으로 기능 정합성을 확인한 프로젝트입니다. 명령어/데이터 메모리를 분리한 하버드 구조로 Fetch와 메모리 접근을 병렬화했습니다.

개발 환경: Vivado · VSCode 연동 · Verilog HDL


주요 특징
RV32I ISA 구현 — R / I / IL / S / B / U / J 7개 명령어 타입 지원
하버드 구조 — 명령어 메모리와 데이터 메모리 분리로 병렬 접근
Datapath + Control Unit — opcode·funct3·funct7 디코딩 기반 제어신호 생성
분기 처리 — comparator 판정 + PC MUX로 pc+4 / branch / jal / jalr 경로 선택
검증 완료 — 전 명령어 타입 파형 검증 + 어셈블리 실행 검증


아키텍처
        ┌─────────────┐      ┌──────────────┐

  PC ─► │ Instr Memory│ ───► │ Control Unit │─► 제어신호

        └─────────────┘      └──────────────┘

                                    │

        ┌─────────────────────────────────────────┐

        │  Register File ─ ALU ─ Imm Gen ─ Data Mem │

        └─────────────────────────────────────────┘

                │

      PC 분기 MUX ◄─ pc+4 / branch / jal / jalr

alu_src: ALU 입력을 레지스터 값 / immediate 중 선택
comparator: 분기(branch) 조건 판정
PC MUX: 다음 PC 경로 선택


폴더 구조
riscv-single-cycle/

├── rtl/      # 설계 소스 (datapath, control unit, ALU, regfile, imm gen 등)

├── tb/       # 타입별 테스트벤치

├── sim/      # 어셈블리 프로그램 / ROM 메모리 이미지

├── docs/     # 발표자료, 블록 다이어그램

└── README.md


검증 내용
① 타입별 시뮬레이션 검증 각 명령어 타입(R/I/IL/S/B/U/J)별 시나리오를 작성하고, 파형에서 레지스터·메모리·PC 변화를 기대값과 대조하여 전 타입의 동작 정합성을 확인.

② 어셈블리 실행 검증 1~10 누적합(adder) C 코드를 어셈블리로 변환해 ROM에 적재·실행, main 함수 실행으로 최종 결과값 55 확인.


트러블슈팅
JALR 타깃 주소 정렬 문제 (rs1 + imm)의 LSB를 덧셈 전에 0으로 만들면 올림수(carry)가 유실되는 문제 발견. → 덧셈을 먼저 수행한 뒤 결과의 LSB를 0으로 마스킹하여 해결.


발표 자료
프로젝트 발표 자료는 docs/ 폴더에서 확인할 수 있습니다.


사용 기술
Verilog HDL · RISC-V RV32I ISA · Harvard Architecture · Datapath/Control Unit 설계 · Vivado



작성자: 최은수 (@eunsu1209)
