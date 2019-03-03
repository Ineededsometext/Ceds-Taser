--[[
              _____           _  _       _______                      
             / ____|         | |( )     |__   __|                     
            | |      ___   __| ||/ ___     | |  __ _  ___   ___  _ __ 
            | |     / _ \ / _` |  / __|    | | / _` |/ __| / _ \| '__|
            | |____|  __/| (_| |  \__ \    | || (_| |\__ \|  __/| |   
             \_____|\___| \__,_|  |___/    |_| \__,_||___/ \___||_| 
]]

if ( CLIENT ) then
    SWEP.WepSelectIcon = surface.GetTextureID( "vgui/entities/admin_taser" )
    SWEP.BounceWeaponIcon = false

    killicon.Add( "admin_taser", "vgui/entities/killicon_taser", Color( 255, 255, 255, 255 ) )
end

SWEP.PrintName = "Admin Taser"
SWEP.Author = "Ced" 
SWEP.Purpose = "People who have been tased by this won't be released until you reload."
SWEP.Instructions = "Mouse1 to shoot, Mouse2 to electrocute, Reload to release."
SWEP.Category = "Ced's Weapons"
SWEP.Slot = 1
SWEP.AdminOnly = true

SWEP.HoldType  = "revolver"

SWEP.Primary.ClipSize = -1
SWEP.Primary.Automatic = true
SWEP.Primary.Ammo = "none"
SWEP.Primary.Sound = "ced/taser/taser_shot.wav"

SWEP.Secondary.Ammo = "none"
SWEP.Secondary.ClipSize = -1
SWEP.Secondary.Automatic = true
SWEP.Secondary.Ammo = "none"

SWEP.Spawnable = true

SWEP.UseHands = true

-- c_model by Buu342.
-- You can find this model at Buu342's addon: http://steamcommunity.com/sharedfiles/filedetails/?id=239687689 
SWEP.ViewModel = "models/csgo/weapons/c_csgo_taser.mdl"
SWEP.WorldModel = "models/csgo/weapons/w_eq_taser.mdl"

SWEP.Prongs = {}
SWEP.Deploying = false
SWEP.ReleaseDelay = CurTime()

function SWEP:Deploy()
    self:SetHoldType( self.HoldType )
    self:SendWeaponAnim( ACT_VM_DRAW )

    self.Owner:EmitSound( "ced/taser/taser_draw.wav" )

    self.Deploying = true
    timer.Simple( self.Owner:GetViewModel():SequenceDuration(), function()
        if ( IsValid( self ) ) then
            self.Deploying = false
        end
    end )

    if ( SERVER ) then
        self.ShootPos = ents.Create( "prop_physics" )
        self.ShootPos:SetModel( "models/hunter/blocks/cube025x025x025.mdl" )
        self.ShootPos:SetNoDraw( true )
        self.ShootPos:SetCollisionGroup( COLLISION_GROUP_IN_VEHICLE )
		
        if ( not self.Owner:Crouching() ) then
			self.ShootPos:SetPos( self:GetBonePosition( self:LookupBone( "frame" ) ) + Vector( 0, 0, 68 ) )
		else
			self.ShootPos:SetPos( self:GetBonePosition( self:LookupBone( "frame" ) ) + Vector( 0, 0, 32 ) )
		end
		
        self.ShootPos:Spawn()
    end

    return true
end

function SWEP:Holster()
    if ( SERVER ) then
        if ( IsValid( self.ShootPos ) ) then
            self.ShootPos:Remove()
        end

        if ( IsValid( self.Prong ) ) then
            self.Prong:Remove()
        end

        if ( IsValid( self.Cable ) and IsValid( self.Cable2 ) ) then
            self.Cable:Remove()
            self.Cable2:Remove()
        end

        self.Prongs = {}
    end

    return true
end

function SWEP:Think()
    if ( SERVER and IsValid( self.ShootPos ) ) then
		if ( not self.Owner:Crouching() ) then
			self.ShootPos:SetPos( self:GetBonePosition( self:LookupBone( "frame" ) ) + Vector( 0, 0, 68 ) )
		else
			self.ShootPos:SetPos( self:GetBonePosition( self:LookupBone( "frame" ) ) + Vector( 0, 0, 32 ) )
		end
		
        self.ShootPos:SetAngles( Angle( 0, 0, 0 ) )
    elseif ( SERVER ) then
        self.ShootPos = ents.Create( "prop_physics" )
        self.ShootPos:SetModel( "models/hunter/blocks/cube025x025x025.mdl" )
        self.ShootPos:SetNoDraw( true )
        self.ShootPos:SetCollisionGroup( COLLISION_GROUP_IN_VEHICLE )
		
        if ( not self.Owner:Crouching() ) then
			self.ShootPos:SetPos( self:GetBonePosition( self:LookupBone( "frame" ) ) + Vector( 0, 0, 68 ) )
		else
			self.ShootPos:SetPos( self:GetBonePosition( self:LookupBone( "frame" ) ) + Vector( 0, 0, 32 ) )
		end
		
        self.ShootPos:Spawn()
    end
end

function SWEP:PrimaryAttack()
    if ( self.Deploying ) then return false end

    if ( SERVER ) then
        self.Owner:EmitSound( self.Primary.Sound )

        local tr = self.Owner:GetEyeTrace()

        self.Prong = ents.Create( "admin_taser_prong" )
		self.Prong.Taser = self
        self.Prong:SetAngles( self.Owner:EyeAngles() )
        self.Prong:SetPos( self.Owner:GetShootPos() )
        self.Prong:SetAngles( self.Owner:EyeAngles() )
        self.Prong.Owner = self.Owner
        self.Prong:Spawn()

        table.insert( self.Prongs, #self.Prongs + 1, self.Prong )

        local phys = self.Prong:GetPhysicsObject()
		local range = GetConVar( "taser_range" ):GetFloat()
        phys:ApplyForceCenter( self.Owner:GetAimVector():GetNormalized() *  math.pow( tr.HitPos:Length(), 8 ) )
        
        self.Cable = constraint.Rope( self.ShootPos, self.Prong, 0, 0, Vector( 0, 0, 0 ), Vector( 0, 0, 0 ), range, 0, 0, 0.25, "cable/blue_elec", false )
        self.Cable2 = constraint.Rope( self.ShootPos, self.Prong, 0, 0, Vector( 0, 0, -1 ), Vector( 0, 0, 0 ), range, 0, 0, 0.25, "cable/blue_elec", false )
    end

    self:ShootEffects()
    self:SetNextPrimaryFire( CurTime() + GetConVar( "taser_delay" ):GetFloat() )
end

function SWEP:SecondaryAttack()
    if ( self.Prongs == nil ) then return end

    for _, p in pairs( self.Prongs ) do
        if ( IsValid( p.Target ) ) then
            p.Target:TakeDamage( GetConVar( "taser_damage" ):GetFloat(), self.Owner, self )
        end
    end

    self.Owner:SetAnimation( PLAYER_ATTACK1 )
end

function SWEP:Reload()
	if ( self.ReleaseDelay <= CurTime() ) then
		for _, p in pairs( self.Prongs ) do
			p.Released = true
		end
	
		self.ReleaseDelay = CurTime() + 0.25
	end
end

function SWEP:ShootEffects()
    self.Weapon:SendWeaponAnim( ACT_VM_PRIMARYATTACK )
    self.Owner:SetAnimation( PLAYER_ATTACK1 )
end