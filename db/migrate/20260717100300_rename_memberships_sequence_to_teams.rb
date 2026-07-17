class RenameMembershipsSequenceToTeams < ActiveRecord::Migration[8.1]
  # rename_table :memberships, :teams left the sequence named memberships_id_seq,
  # which the schema dumper then pinned as an explicit default on teams.id. Databases
  # built from that schema have no such sequence. IF EXISTS keeps this a no-op on
  # databases already created with the correct name.
  def up
    execute "ALTER SEQUENCE IF EXISTS memberships_id_seq RENAME TO teams_id_seq"
  end

  def down
    execute "ALTER SEQUENCE IF EXISTS teams_id_seq RENAME TO memberships_id_seq"
  end
end
