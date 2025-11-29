-- Teams table
CREATE TABLE IF NOT EXISTS teams (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    max_members INT DEFAULT 5,
    created_by UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Team members table
CREATE TABLE IF NOT EXISTS team_members (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    team_id UUID NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    role VARCHAR(20) DEFAULT 'member', -- 'leader' or 'member'
    joined_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(team_id, user_id)
);

-- Team chat messages table
CREATE TABLE IF NOT EXISTS team_messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    team_id UUID NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    message TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Add team_id to event_registrations
ALTER TABLE event_registrations 
ADD COLUMN IF NOT EXISTS team_id UUID REFERENCES teams(id) ON DELETE SET NULL;

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_teams_event_id ON teams(event_id);
CREATE INDEX IF NOT EXISTS idx_team_members_team_id ON team_members(team_id);
CREATE INDEX IF NOT EXISTS idx_team_members_user_id ON team_members(user_id);
CREATE INDEX IF NOT EXISTS idx_team_messages_team_id ON team_messages(team_id);
CREATE INDEX IF NOT EXISTS idx_event_registrations_team_id ON event_registrations(team_id);

-- Enable RLS
ALTER TABLE teams ENABLE ROW LEVEL SECURITY;
ALTER TABLE team_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE team_messages ENABLE ROW LEVEL SECURITY;

-- RLS Policies for teams
CREATE POLICY "Anyone can view teams" ON teams FOR SELECT USING (true);
CREATE POLICY "Authenticated users can create teams" ON teams FOR INSERT WITH CHECK (auth.uid() = created_by);
CREATE POLICY "Team creator can update team" ON teams FOR UPDATE USING (auth.uid() = created_by);
CREATE POLICY "Team creator can delete team" ON teams FOR DELETE USING (auth.uid() = created_by);

-- RLS Policies for team_members
CREATE POLICY "Anyone can view team members" ON team_members FOR SELECT USING (true);
CREATE POLICY "Team leader can add members" ON team_members FOR INSERT WITH CHECK (
    EXISTS (
        SELECT 1 FROM team_members tm
        WHERE tm.team_id = team_members.team_id
        AND tm.user_id = auth.uid()
        AND tm.role = 'leader'
    )
    OR auth.uid() = user_id -- Users can join themselves
);
CREATE POLICY "Team members can leave" ON team_members FOR DELETE USING (auth.uid() = user_id);

-- RLS Policies for team_messages
CREATE POLICY "Team members can view messages" ON team_messages FOR SELECT USING (
    EXISTS (
        SELECT 1 FROM team_members
        WHERE team_members.team_id = team_messages.team_id
        AND team_members.user_id = auth.uid()
    )
);
CREATE POLICY "Team members can send messages" ON team_messages FOR INSERT WITH CHECK (
    EXISTS (
        SELECT 1 FROM team_members
        WHERE team_members.team_id = team_messages.team_id
        AND team_members.user_id = auth.uid()
    )
    AND auth.uid() = user_id
);
