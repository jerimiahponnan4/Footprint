# 🌱 Carbon Footprint Ledger

A decentralized carbon footprint tracking system built on Stacks blockchain using Clarity smart contracts. Track, monitor, and reduce your personal or organizational carbon emissions with transparency and accountability.

## 🚀 Features

- 📊 **Emission Tracking**: Log carbon emissions by category with detailed descriptions
- 🌿 **Carbon Offsets**: Purchase and track carbon offset projects
- 🎯 **Emission Targets**: Set and monitor emission reduction goals
- 🏆 **Leaderboard**: Compare your carbon footprint with others
- ✅ **Carbon Neutral Status**: Automatically calculate if you're carbon neutral
- 📈 **Progress Tracking**: Monitor your journey towards emission targets

## 🛠️ Getting Started

### Prerequisites

- Clarinet CLI installed
- Stacks wallet for testing

### Installation

```bash
git clone <your-repo>
cd carbon-footprint-ledger
clarinet check
```

## 📋 Usage

### Create Your Profile

First, create your carbon footprint profile:

```clarity
(contract-call? .Footprint create-profile)
```

### Track Emissions

Add emissions by category:

```clarity
(contract-call? .Footprint add-emission "transportation" u500 "Flight to NYC - round trip")
(contract-call? .Footprint add-emission "energy" u200 "Monthly electricity usage")
(contract-call? .Footprint add-emission "food" u150 "Weekly grocery shopping")
```

### Purchase Carbon Offsets

Offset your emissions:

```clarity
(contract-call? .Footprint add-offset "Reforestation Project Brazil" u300 u50)
(contract-call? .Footprint add-offset "Solar Farm Initiative" u200 u35)
```

### Set Emission Targets

Define your reduction goals:

```clarity
(contract-call? .Footprint set-emission-target u1000)
```

## 🔍 Read-Only Functions

### Check Your Profile

```clarity
(contract-call? .Footprint get-user-profile 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
```

### View Net Footprint

```clarity
(contract-call? .Footprint get-net-footprint 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
```

### Check Carbon Neutral Status

```clarity
(contract-call? .Footprint is-carbon-neutral 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
```

### Monitor Target Progress

```clarity
(contract-call? .Footprint calculate-target-progress 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
```

## 📊 Data Structure

### User Profile
- Total emissions (kg CO2)
- Total offsets (kg CO2)
- Net footprint (emissions - offsets)
- Account creation timestamp

### Emissions
- Category (transportation, energy, food, etc.)
- Amount (kg CO2)
- Description
- Timestamp

### Offsets
- Project name
- Amount (kg CO2)
- Price paid
- Timestamp

## 🎯 Emission Categories

Common categories to track:
- `transportation` - Flights, driving, public transport
- `energy` - Electricity, heating, cooling
- `food` - Diet-related emissions
- `consumption` - Purchases, goods, services
- `waste` - Waste generation and disposal

## 🏆 Leaderboard System

The contract maintains a leaderboard ranking users by their net carbon footprint. Lower (more negative) footprints rank higher, encouraging carbon neutrality and negative emissions.

## 🔒 Security Features

- User authentication via transaction sender
- Input validation for all parameters
- Error handling for edge cases
- Immutable emission and offset records

## 🌍 Environmental Impact

This platform promotes:
- ♻️ **Transparency** in carbon accounting
- 🎯 **Accountability** through public records
- 🌱 **Behavior Change** via gamification
- 💚 **Carbon Neutrality** achievement tracking

## 🚀 Future Enhancements

- Integration with IoT devices for automatic tracking
- Corporate dashboard for organizations
- Carbon credit marketplace
- Mobile app interface
- API for third-party integrations

## 📄 License

MIT License - Build a greener future together! 🌍

