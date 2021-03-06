require 'rails_helper'

RSpec.describe GamesController, type: :request do
  include AuthHelper
  include ResponseHelpers

  before(:context) do
    @current_user = Fabricate(:user, password: '12341234')
  end

  describe "show game displays started game" do
    let(:game) { Fabricate(:game) }

    before(:each) do
      get "/games/#{game.id}", headers: headers
    end

    it "returns a game object on update" do
      expect(body["id"]).to eq(game.id)
    end

    it "returns the player roles" do
      role = body["players"].first['role']
      expect(Player.roles.keys.include?(role)).to eq(true)
    end

    it "returns the player position" do
      expect(body["players"].first['position']) .to eq('one')
    end

    it "returns first player's location" do
      expect(body["players"].first['location_staticid']).to eq('0')
    end
  end

  describe "display created games" do
    let!(:current_user) { Fabricate(:user) }
    let!(:game) { Fabricate(:game, owner: current_user) }
    let!(:game_two) { Fabricate(:game) }
    let!(:player) { Fabricate(:player, game: game_two, user: current_user) }

    before(:each) do
      get "/games", headers: headers
    end

    it "displays created and joined games" do
      expect(body['games'].count).to eq(2)
    end
  end

  describe "create game" do
    it "creates a game with started set to false" do
      post "/games", params: {}, headers: headers
      expect(body['game']['id']).to eq(Game.last.id)
      expect(Game.last.started?).to be(false)
    end

    it "creates a game with turn_nr set to 1" do
      post "/games", params: {}, headers: headers
      expect(body['game']['id']).to eq(Game.last.id)
      expect(Game.last.turn_nr).to eq(1)
    end

    it "creates a game with actions_taken set to 0" do
      post "/games", params: {}, headers: headers
      expect(body['game']['id']).to eq(Game.last.id)
      expect(Game.last.actions_taken).to eq(0)
    end

    it "sets game owner's player current location to Atlanta" do
      post "/games", params: {}, headers: headers
      location = @current_user.players.find_by(game: Game.last).location
      expect(location.name).to eq('Atlanta')
    end

    it "assigns game role to player" do
      post "/games", params: {}, headers: headers
      player_role = Game.last.players.first.role
      expect(Player.roles.keys.include?(player_role)).to be(true)
    end

    it "assigns game a name when created" do
      post "/games", params: {}, headers: headers
      player_role = Game.last.name
      expect(Game.last.name).to_not be_nil
    end
  end

  describe "update game" do
    let(:game) { Fabricate(:game, owner: @current_user, status: 'not_started') }

    it "does not start a game with only one player" do
      put "/games/#{game.id}", params: {
        nr_of_epidemic_cards: 4
      }.to_json, headers: headers
      expect(error).to eq(I18n.t("games.minimum_number_of_players"))
    end

    it "errors out if number of epidemic cards is not provided" do
      player_two = Fabricate(:player, game: game)
      put "/games/#{game.id}", params: {}, headers: headers
      expect(error).to eq(I18n.t("games.incorrect_nr_of_epidemic_cards"))
    end

    it "errors out if game has already started" do
      game.started!
      put "/games/#{game.id}", params: {}, headers: headers
      expect(error).to eq(I18n.t("games.already_started"))
    end

    context "with valid params" do
      before(:all) do
        @game = Fabricate(:game, owner: @current_user, status: 'not_started')
        @player_one = @game.players.find_by(user: @current_user)
        @player_two = Fabricate(:player, game: @game)
        put "/games/#{@game.id}", params: {
          nr_of_epidemic_cards: 4
        }.to_json, headers: headers
      end

      it "creates cures markers" do
        expect(@game.cure_markers.map(&:color).uniq.count).to eq(4)
        expect(@game.cure_markers.map(&:cured).uniq).to eq([false])
        expect(@game.cure_markers.map(&:eradicated).uniq).to eq([false])
      end

      it "assigns a color to infections" do
        expect(@game.infections.last.color).to_not be_nil
      end

      it "creates a research station in atlanta" do
        expect(@game.research_stations.first.city_staticid).to eq('6')
      end

      it "assigns cards to players" do
        expect(@player_one.reload.cards_composite_ids.present?).to be(true)
        expect(@player_two.reload.cards_composite_ids.present?).to be(true)
      end

      it "sets game player cards" do
        expect(@game.reload.unused_player_card_ids.count).to eq(49)
      end

      it "sets game player turns" do
        expect(@game.reload.player_turn_ids.present?).to be(true)
      end

      it "sets game started to true" do
        expect(@game.reload.started?).to be(true)
      end

      it "creates start game infections" do
        expect(@game.infections.where(quantity: 3).count).to eq(3)
        expect(@game.infections.where(quantity: 2).count).to eq(3)
        expect(@game.infections.where(quantity: 1).count).to eq(3)
      end

      it "stores used_infection_card_city_staticids" do
        expect(@game.reload.used_infection_card_city_staticids.count).to eq(9)
      end

      it "stores unused_infection_card_city_staticids" do
        expect(@game.reload.unused_infection_card_city_staticids.count).to eq(39)
      end

      it "returns a game object on update" do
        expect(body["id"]).to eq(@game.id)
      end

      it "returns the player roles" do
        expect(body["players"].first['role']).to eq(@player_one.role)
      end

      it "returns the player position" do
        expect(body["players"].first['position']) .to eq('one')
        expect(body["players"].second['position']) .to eq('two')
      end

      it "returns first player's location" do
        expect(body["players"].first['location_staticid']).to eq('6')
      end

      it "returns second player's location" do
        expect(body["players"].second['location_staticid']).to eq('6')
      end
    end
  end
end
