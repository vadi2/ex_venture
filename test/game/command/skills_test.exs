defmodule Game.Command.SkillsTest do
  use Data.ModelCase
  doctest Game.Command.Skills

  alias Game.Command.Skills
  alias Game.Session.State

  @socket Test.Networking.Socket
  @room Test.Game.Room

  setup do
    npc = %{id: 1, name: "Bandit"}

    room = @room._room()
    |> Map.put(:npcs, [npc])

    @room.set_room(room)
    @socket.clear_messages
    start_and_clear_skills()

    slash = create_skill(%{
      level: 1,
      name: "Slash",
      points: 2,
      command: "slash",
      description: "Slash",
      user_text: "Slash at your {target}",
      usee_text: "You were slashed at",
      effects: [%{kind: "damage", type: "slashing", amount: 0}],
    })
    insert_skill(slash)

    save = %{base_save() | level: 1, stats: %{strength: 10, skill_points: 10}, wearing: %{}, skill_ids: [slash.id]}
    user = %{id: 10, name: "Player", save: save}

    state = %State{
      socket: :socket,
      state: "active",
      mode: "commands",
      skills: %{},
      user: user,
      save: save
    }

    {:ok, %{state: state, user: user, save: save, slash: slash}}
  end

  describe "parsing skills" do
    test "parsing skills based on the user", %{state: state, slash: slash} do
      assert %{text: "slash", module: Skills, args: {^slash, "slash"}} = Skills.parse_skill("slash", state.user)
      assert {:error, :bad_parse, "look"} = Skills.parse_skill("look", state.user)
    end

    test "parses the skill but marks as not high enough level if they have the skill but too low", %{state: state} do
      kick = create_skill(%{
        level: 2,
        name: "Kick",
        points: 2,
        command: "kick",
        description: "Kick",
        user_text: "Kick at your {target}",
        usee_text: "You were kicked at",
        effects: [%{kind: "damage", type: "bludgeoning", amount: 0}],
      })
      insert_skill(kick)

      user = state.user
      user = %{user | save: %{user.save | skill_ids: [kick.id | user.save.skill_ids]}}

      assert %{text: "kick", module: Skills, args: {^kick, :level_too_low}} = Skills.parse_skill("kick", user)
    end

    test "parses the skill but marks as not usable if skill exists but user does not have", %{state: state} do
      kick = create_skill(%{
        level: 1,
        name: "Kick",
        points: 2,
        command: "kick",
        description: "Kick",
        user_text: "Kick at your {target}",
        usee_text: "You were kicked at",
        effects: [%{kind: "damage", type: "bludgeoning", amount: 0}],
      })
      insert_skill(kick)

      assert %{text: "kick", module: Skills, args: {^kick, :not_known}} = Skills.parse_skill("kick", state.user)
    end
  end

  describe "viewing skills" do
    setup do
      %{level: 5, name: "Kick"}
      |> create_skill()
      |> insert_skill()

      :ok
    end

    test "view skill information", %{state: state} do
      :ok = Skills.run({}, state)

      [{_socket, look}] = @socket.get_echos()
      assert Regex.match?(~r(slash), look)
      assert Regex.match?(~r(2sp), look)

      refute Regex.match?(~r(kick)i, look)
    end

    test "view skill information -all", %{state: state} do
      :ok = Skills.run({:all}, state)

      [{_socket, look}] = @socket.get_echos()
      assert Regex.match?(~r(slash)i, look)
      refute Regex.match?(~r(kick)i, look)
    end
  end

  test "using a skill", %{state: state, save: save, slash: slash} do
    state = %{state | save: Map.merge(save, %{room_id: 1}), target: {:npc, 1}}

    {:skip, :prompt, state} = Skills.run({slash, "slash"}, state)
    assert state.save.stats.skill_points == 8
    assert state.skills[slash.id]

    [{_socket, look}] = @socket.get_echos()
    assert Regex.match?(~r(Slash), look)
  end

  test "using a skill - set your target", %{state: state, save: save, slash: slash} do
    state = %{state | save: Map.merge(save, %{room_id: 1}), target: nil}

    {:skip, :prompt, state} = Skills.run({slash, "slash bandit"}, state)
    assert state.save.stats.skill_points == 8
    assert state.target == {:npc, 1}

    [_, {_socket, look}] = @socket.get_echos()
    assert Regex.match?(~r(Slash), look)
  end

  test "using a skill - change your target", %{state: state, save: save, slash: slash} do
    state = %{state | save: Map.merge(save, %{room_id: 1}), target: {:user, 3}}

    {:skip, :prompt, state} = Skills.run({slash, "slash bandit"}, state)
    assert state.save.stats.skill_points == 8
    assert state.target == {:npc, 1}

    [_, {_socket, look}] = @socket.get_echos()
    assert Regex.match?(~r(Slash), look)
  end

  test "using a skill - target not found", %{state: state, save: save, slash: slash} do
    state = %{state | save: Map.merge(save, %{room_id: 1}), target: {:npc, 2}}
    :ok = Skills.run({slash, "slash"}, state)

    [{_socket, look}] = @socket.get_echos()
    assert Regex.match?(~r(Your target could not), look)
  end

  test "using a skill - with no target", %{state: state, slash: slash} do
    :ok = Skills.run({slash, "slash"}, %{state | target: nil})

    [{_socket, look}] = @socket.get_echos()
    assert Regex.match?(~r(You don't have), look)
  end

  test "using a skill - not enough skill points", %{state: state, save: save, slash: slash} do
    stats = %{save.stats | skill_points: 1}
    state = %{state | save: Map.merge(save, %{room_id: 1, stats: stats}), target: {:npc, 1}}

    {:update, ^state} = Skills.run({slash, "slash"}, state)

    [{_socket, look}] = @socket.get_echos()
    assert Regex.match?(~r(You don't have), look)
  end

  test "using a skill - too soon", %{state: state, save: save, slash: slash} do
    state =
      state
      |> Map.put(:skills, %{slash.id => Timex.now()})
      |> Map.put(:save, Map.merge(save, %{room_id: 1}))
      |> Map.put(:target, {:npc, 1})

    :ok = Skills.run({slash, "slash"}, state)

    [{_socket, look} | _] = @socket.get_echos()
    assert Regex.match?(~r(not ready)i, look)
  end

  test "using a skill - not high enough level", %{state: state, save: save, slash: slash} do
    state = %{state |save: Map.merge(save, %{room_id: 1}), target: {:npc, 1}}
    slash = %{slash | level: 2}

    :ok = Skills.run({slash, "slash"}, state)

    [{_socket, look}] = @socket.get_echos()
    assert Regex.match?(~r(You are not high), look)
  end
end
