# 🎮 Gametrax - Tournament Smart Contract

> 🏆 Lock entry fees and auto-distribute winnings with blockchain transparency!

## 📋 Overview

Gametrax is a Clarity smart contract that enables trustless gaming tournaments on the Stacks blockchain. Players can join tournaments by paying entry fees, which are automatically locked in the contract and distributed to winners upon completion.

## ✨ Features

- 🎯 **Create Tournaments** - Set up tournaments with custom entry fees and participant limits
- 💰 **Automatic Prize Pool** - Entry fees are automatically collected and secured
- 🔒 **Trustless Execution** - No intermediaries needed for prize distribution
- 🏅 **Winner Declaration** - Tournament creators can declare winners and trigger payouts
- 💸 **Refund System** - Cancelled tournaments automatically refund participants
- 📊 **Tournament Tracking** - View tournament status, participants, and prize pools

## 🚀 Quick Start

### Prerequisites
- Clarinet installed
- Stacks wallet with STX tokens

### Installation

```bash
git clone <your-repo>
cd gametrax
clarinet check
```

## 🎮 Usage

### Creating a Tournament

```clarity
(contract-call? .gametrax create-tournament "Epic Battle Royale" u1000000 u10)
```

### Joining a Tournament

```clarity
(contract-call? .gametrax join-tournament u1)
```

### Starting a Tournament

```clarity
(contract-call? .gametrax start-tournament u1)
```

### Declaring a Winner

```clarity
(contract-call? .gametrax declare-winner u1 'SP1ABCD...)
```

## 📖 Contract Functions

### Public Functions

| Function | Description | Parameters |
|----------|-------------|------------|
| `create-tournament` | 🎯 Create a new tournament | name, entry-fee, max-participants |
| `join-tournament` | 🎮 Join an existing tournament | tournament-id |
| `start-tournament` | 🚀 Start a tournament (creator only) | tournament-id |
| `declare-winner` | 🏆 Declare winner and distribute prize | tournament-id, winner |
| `cancel-tournament` | ❌ Cancel a tournament | tournament-id |
| `refund-participant` | 💸 Refund a participant from cancelled tournament | tournament-id, participant |

### Read-Only Functions

| Function | Description | Returns |
|----------|-------------|---------|
| `get-tournament` | 📊 Get tournament details | Tournament data |
| `get-tournament-status` | 🔍 Get tournament status | Status string |
| `get-tournament-prize-pool` | 💰 Get current prize pool | Prize amount |
| `is-tournament-participant` | ✅ Check if user is participant | Boolean |
| `can-join-tournament` | 🎯 Check if tournament is joinable | Boolean |

## 🔄 Tournament Lifecycle

1. **🎯 Creation** - Tournament creator sets parameters
2. **👥 Registration** - Players join by paying entry fees
3. **🚀 Start** - Creator starts the tournament when ready
4. **🎮 Play** - Gaming happens off-chain
5. **🏆 Completion** - Winner declared and prize distributed

## 💡 Example Workflow

```bash
# Create tournament
clarinet console
```

```clarity
(contract-call? .gametrax create-tournament "Weekly Championship" u500000 u8)
(contract-call? .gametrax join-tournament u1)
(contract-call? .gametrax start-tournament u1)
(contract-call? .gametrax declare-winner u1 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7)
```

## 🛡️ Security Features

- ✅ Entry fees locked in contract until completion
- ✅ Only tournament creators can declare winners
- ✅ Automatic refunds for cancelled tournaments
- ✅ Participant validation and duplicate prevention
- ✅ Tournament status management

## 🧪 Testing

```bash
clarinet test
```

## 📝 Error Codes

| Code | Description |
|------|-------------|
| u100 | Owner only operation |
| u101 | Tournament not found |
| u102 | Already exists |
| u103 | Invalid status |
| u104 | Insufficient payment |
| u105 | Tournament full |
| u106 | Tournament already started |
| u107 | Not a participant |
| u108 | Invalid winner |
| u109 | Already finalized |

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## 📄 License

MIT License - see LICENSE file for details

---

**🎮 Ready to revolutionize gaming tournaments? Deploy Gametrax today!** 🚀


