# nn_postman

Multiplayer mail delivery job for FiveM — built on the same architecture as `nn_garbagejob`.

## Dependencies

- [community_bridge](https://github.com/The-Order-of-the-Unicorn/community_bridge) (QBCore / ESX / QBox)
- oxmysql

## Install

1. Place `nn_postman` in your `resources` folder
2. Add to `server.cfg`:
   ```
   ensure community_bridge
   ensure oxmysql
   ensure nn_postman
   ```
3. Restart the server (creates `player_levels_postman` table automatically)

## Job location

**GO Postal depot** — map blip at the configured hub (`Config.job_search_zone`).

Target the zone and choose **Browse mail routes**.

## Gameplay

1. Pick a zone (Los Santos / Sandy Shores / Paleto Bay) and difficulty
2. Optional: invite a duo partner from the job board
3. Spawn the post van, drive to 5 stops
4. At each stop:
   - **Grab Mail from Van** (rear of van)
   - Complete **2 deliveries** using the stop-specific interaction
   - **Sort Route Satchel** at the van before the next stop
5. Return the van to the depot for payout + XP

## Creative stop types

| Type | What you do |
|------|-------------|
| `mailbox` | Drop letters in a roadside mailbox |
| `door_knock` | Knock on the door and hand mail to the resident |
| `package` | Carry a heavy box from the van (slow walk) |
| `cluster` | Sort letters into apartment cluster box slots |
| `registered` | Collect a signature on a clipboard |
| `newspaper` | Toss a rolled paper onto the porch |
| `dog_yard` | Wait for the barking dog to settle, then deliver |

Stop types rotate per route in `shared/config.lua`.

## Config

Edit `shared/config.lua` for:

- Depot / blip location
- Delivery coordinates (`Config.DeliveryStops`)
- Stop type layouts (`Config.StopTypesByMission`)
- Payouts (`Config.MissionRewards`)
- Van model (`Config.PostVanModel`)

## NUI rebuild

```bash
cd web
npm install
npm run build
```
"# nn_postman" 
