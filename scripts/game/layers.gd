class_name Layers
## Physics layer bits.

const WORLD := 1
const SOLDIER := 2 # movement capsules
const HITBOX := 4 # bullet hit zones on soldiers
const PROJECTILE := 8 # grenades, rockets, equipment
const INTERACT := 16 # crates, flags, pickups
const VEHICLE := 32 # streak rewards that can be shot down

const BULLET_MASK := WORLD | HITBOX | VEHICLE
const LOS_MASK := WORLD
