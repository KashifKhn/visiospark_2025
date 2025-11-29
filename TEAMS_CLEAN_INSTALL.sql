-- ============================================
-- TEAMS SYSTEM - CLEAN INSTALL
-- Completely safe - handles all edge cases
-- ============================================

-- Step 1: Drop policies ONLY if tables exist
-- ============================================

DO $$ 
BEGIN
    -- Drop teams policies if table exists
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'teams') THEN
        DROP POLICY IF EXISTS "Anyone can view teams" ON teams;
        DROP POLICY IF EXISTS "Authenticated users can create teams" ON teams;
        DROP POLICY IF EXISTS "Team creator can update team" ON teams;
        DROP POLICY IF EXISTS "Team creator can delete team" ON teams;
    END IF;

    -- Drop team_members policies if table exists
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'team_members') THEN
        DROP POLICY IF EXISTS "Anyone can view team members" ON team_members;
        DROP POLICY IF EXISTS "Team leader can add members" ON team_members;
        DROP POLICY IF EXISTS "Team members can leave" ON team_members;
    END IF;

    -- Drop team_messages policies if table exists
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'team_messages') THEN
        DROP POLICY IF EXISTS "Team members can view messages" ON team_messages;
        DROP POLICY IF EXISTS "Team members can send messages" ON team_messages;
    END IF;
END $$;


-- Step 2: Drop tables if they exist
-- ============================================

DROP TABLE IF EXISTS team_messages CASCADE;
DROP TABLE IF EXISTS team_members CASCADE;
DROP TABLE IF EXISTS teams CASCADE;


-- Step 3: Remove team_id from event_registrations if exists
-- ============================================

DO $$ 
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'event_registrations' 
        AND column_name = 'team_id'
    ) THEN
        ALTER TABLE event_registrations DROP COLUMN team_id;
    END IF;
END $$;


-- Step 4: Create all tables fresh
-- ============================================

-- Teams table
CREATE TABLE teams (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    max_members INT DEFAULT 5,
    creator_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Team members table
CREATE TABLE team_members (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    team_id UUID NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    role VARCHAR(20) DEFAULT 'member',
    joined_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(team_id, user_id)
);

-- Team chat messages table
CREATE TABLE team_messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    team_id UUID NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    message TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Add team_id to event_registrations
ALTER TABLE event_registrations 
ADD COLUMN team_id UUID REFERENCES teams(id) ON DELETE SET NULL;


-- Step 5: Create indexes
-- ============================================

CREATE INDEX idx_teams_event_id ON teams(event_id);
CREATE INDEX idx_teams_creator_id ON teams(creator_id);
CREATE INDEX idx_team_members_team_id ON team_members(team_id);
CREATE INDEX idx_team_members_user_id ON team_members(user_id);
CREATE INDEX idx_team_messages_team_id ON team_messages(team_id);
CREATE INDEX idx_team_messages_user_id ON team_messages(user_id);
CREATE INDEX idx_event_registrations_team_id ON event_registrations(team_id);


-- Step 6: Enable RLS
-- ============================================

ALTER TABLE teams ENABLE ROW LEVEL SECURITY;
ALTER TABLE team_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE team_messages ENABLE ROW LEVEL SECURITY;


-- Step 7: Create RLS Policies
-- ============================================

-- Teams policies
CREATE POLICY "Anyone can view teams" 
ON teams FOR SELECT 
USING (true);

CREATE POLICY "Authenticated users can create teams" 
ON teams FOR INSERT 
WITH CHECK (auth.uid() = creator_id);

CREATE POLICY "Team creator can update team" 
ON teams FOR UPDATE 
USING (auth.uid() = creator_id);

CREATE POLICY "Team creator can delete team" 
ON teams FOR DELETE 
USING (auth.uid() = creator_id);

-- Team members policies
CREATE POLICY "Anyone can view team members" 
ON team_members FOR SELECT 
USING (true);

CREATE POLICY "Team leader can add members" 
ON team_members FOR INSERT 
WITH CHECK (
    EXISTS (
        SELECT 1 FROM team_members tm
        WHERE tm.team_id = team_members.team_id
        AND tm.user_id = auth.uid()
        AND tm.role = 'leader'
    )
    OR auth.uid() = user_id
);

CREATE POLICY "Team members can leave" 
ON team_members FOR DELETE 
USING (auth.uid() = user_id);

-- Team messages policies
CREATE POLICY "Team members can view messages" 
ON team_messages FOR SELECT 
USING (
    EXISTS (
        SELECT 1 FROM team_members
        WHERE team_members.team_id = team_messages.team_id
        AND team_members.user_id = auth.uid()
    )
);

CREATE POLICY "Team members can send messages" 
ON team_messages FOR INSERT 
WITH CHECK (
    EXISTS (
        SELECT 1 FROM team_members
        WHERE team_members.team_id = team_messages.team_id
        AND team_members.user_id = auth.uid()
    )
    AND auth.uid() = user_id
);


-- Step 8: Verify installation
-- ============================================

-- Show created tables
SELECT 
    table_name,
    (SELECT COUNT(*) FROM information_schema.columns WHERE table_name = t.table_name) as columns
FROM information_schema.tables t
WHERE table_name IN ('teams', 'team_members', 'team_messages')
ORDER BY table_name;

-- Show teams table structure (verify creator_id exists)
SELECT column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_name = 'teams'
ORDER BY ordinal_position;

-- Show number of policies per table
SELECT 
    schemaname,
    tablename,
    COUNT(*) as policy_count
FROM pg_policies
WHERE tablename IN ('teams', 'team_members', 'team_messages')
GROUP BY schemaname, tablename
ORDER BY tablename;
