require 'rails_helper'

RSpec.describe PlaceInfectionCommand do

  let(:game) { Fabricate(:game) }
  let(:current_player) { game.players.first }
  let(:san_francisco) { WorldGraph.cities[0] }
  let(:manila) { WorldGraph.cities[42] }
  let(:los_angeles) { WorldGraph.cities[1] }
  let(:mexico_city) { WorldGraph.cities[3] }
  let(:atlanta) { WorldGraph.cities[6] }
  let(:montreal) { WorldGraph.cities[7] }
  let(:washington) { WorldGraph.cities[9] }
  let(:london) { WorldGraph.cities[9] }
  let(:madrid) { WorldGraph.cities[9] }
  let(:paris) { WorldGraph.cities[9] }
  let(:chicago) { WorldGraph.cities[2] }
  let(:tokyo) { WorldGraph.cities[45] }
  let(:hong_kong) { WorldGraph.cities[38] }
  let(:ho_chi_min_city) { WorldGraph.cities[41] }
  let(:sydney) { WorldGraph.cities[43] }
  let(:taipei) { WorldGraph.cities[47] }
  let(:command) do
    PlaceInfectionCommand.new(
      game: game,
      staticid: san_francisco.staticid,
      quantity: 3
    )
  end

  it "creates infection for city" do
    current_player.update!(role: Player.roles.keys[0])
    command.call
    expect(game.infections.last.quantity).to eq(3)
  end

  describe "when the current player is a doctor and the diseas is cured" do
    it "does not place an infection" do
      game.cure_markers.find_by(color: san_francisco.color).update!(cured: true)
      Fabricate(:medic, game: game)
      command.call
      expect(game.infections.count).to eq(0)
    end
  end

  describe "when the diseas is eradicated" do
    it "does not place an infection" do
      game.cure_markers.find_by(color: san_francisco.color)
        .update!(cured: true, eradicated: true)
      Fabricate(:operations_expert, game: game)
      command.call
      expect(game.infections.count).to eq(0)
    end
  end

  describe "when the current player is a quarantine specialist" do
    it "does not place an infection in the current city" do
      Fabricate(:quarantine_specialist, game: game)
      command.call
      expect(game.infections.count).to eq(0)
    end

    it "does not place an infection in the neighboring city" do
      Fabricate(
        :quarantine_specialist,
        game: game,
        location_staticid: chicago.staticid
      )
      command.call
      expect(game.infections.count).to eq(0)
    end
  end

  context "when there is an outbreak from the same color" do
    before(:each) do
      Fabricate(:infection, game: game, quantity: 2)
      current_player.update!(role: Player.roles.keys[0])
    end

    it "update the infections in the city with a maximum quantity of 3" do
      command.call
      infections = game.infections.where(city_staticid: san_francisco.staticid)
      expect(infections.total_quantity).to eq(3)
    end

    it "places one blue infection marker in Los Angeles" do
      command.call
      infection = game.infections.find_by(city_staticid: los_angeles.staticid)
      expect(infection.quantity).to eq(1)
      expect(infection.color).to eq('blue')
    end

    it "places one blue infection marker in Tokyo" do
      command.call
      infection = game.infections.find_by(city_staticid: tokyo.staticid)
      expect(infection.quantity).to eq(1)
      expect(infection.color).to eq('blue')
    end

    it "places one blue infection marker in Chicago" do
      command.call
      infection = game.infections.find_by(city_staticid: chicago.staticid)
      expect(infection.quantity).to eq(1)
      expect(infection.color).to eq('blue')
    end

    it "places one blue infection marker in Manila" do
      command.call
      infection = game.infections.find_by(city_staticid: manila.staticid)
      expect(infection.quantity).to eq(1)
      expect(infection.color).to eq('blue')
    end

    it "increases outbreak count" do
      command.call
      expect(game.reload.outbreaks_nr).to eq(1)
    end

    it "marks game as over if there are 8 or more outbreaks" do
      game.update!(outbreaks_nr: 7)
      command.call
      expect(game.reload.finished?).to be(true)
    end

    describe "when there are more than 24 infections of the same color used" do
      it "marks game as over" do
        Fabricate(:iblue, city_staticid: atlanta.staticid, game: game)
        Fabricate(:iblue, city_staticid: madrid.staticid, game: game)
        Fabricate(:iblue, city_staticid: paris.staticid, game: game)
        Fabricate(:iblue, city_staticid: london.staticid, game: game)
        Fabricate(:iblue, city_staticid: chicago.staticid, game: game)
        Fabricate(:iblue, city_staticid: san_francisco.staticid, game: game)
        command.call
        expect(game.reload.finished?).to be(true)
      end
    end

    context "when there is a chain outbreak in the same color" do
      before(:each) do
        Fabricate(
          :infection,
          game: game,
          city_staticid: chicago.staticid,
          color: chicago.color,
          quantity: 3
        )
      end

      it "doesn't place another infection in San Francisco (parent)" do
        command.call
        infections = game.infections
          .where(city_staticid: san_francisco.staticid)
        expect(infections.sum(&:quantity)).to eq(3)
      end

      it "increases outbreak count to two" do
        command.call
        expect(game.reload.outbreaks_nr).to eq(2)
      end

      it "places two blue infection markers in Los Angeles" do
        command.call
        infection = game.infections.find_by(city_staticid: los_angeles.staticid)
        expect(infection.quantity).to eq(2)
        expect(infection.color).to eq('blue')
      end

      it "places one blue infection marker in Mexico City" do
        command.call
        infection = game.infections.find_by(city_staticid: mexico_city.staticid)
        expect(infection.quantity).to eq(1)
        expect(infection.color).to eq('blue')
      end

      it "places one blue infection marker in Atlanta" do
        command.call
        infection = game.infections.find_by(city_staticid: atlanta.staticid)
        expect(infection.quantity).to eq(1)
        expect(infection.color).to eq('blue')
      end

      it "places one blue infection marker in Montreal" do
        command.call
        infection = game.infections.find_by(city_staticid: montreal.staticid)
        expect(infection.quantity).to eq(1)
        expect(infection.color).to eq('blue')
      end

      it "places one blue infection marker in Tokyo" do
        command.call
        infection = game.infections.find_by(city_staticid: tokyo.staticid)
        expect(infection.quantity).to eq(1)
        expect(infection.color).to eq('blue')
      end

      it "places one blue infection marker in Manila" do
        command.call
        infection = game.infections.find_by(city_staticid: manila.staticid)
        expect(infection.quantity).to eq(1)
        expect(infection.color).to eq('blue')
      end

      it "doesn't place additional infections" do
        command.call
        infections = game.infections.where(city_staticid: chicago.staticid)
        expect(infections.total_quantity).to eq(3)
      end
    end

    context "when passing through a city with multiple color outbreak" do
      before(:each) do
        Fabricate(
          :infection,
          game: game,
          city_staticid: manila.staticid,
          color: manila.color,
          quantity: 2
        )
        Fabricate(
          :infection,
          game: game,
          city_staticid: manila.staticid,
          color: san_francisco.color,
          quantity: 1
        )
      end

      it "increases outbreak count" do
        command.call
        expect(game.reload.outbreaks_nr).to eq(2)
      end

      it "doesn't place additional infections" do
        command.call
        infections = game.infections.where(city_staticid: manila.staticid)
        expect(infections.total_quantity).to eq(3)
      end

      it "places one blue infection marker in Los Angeles" do
        command.call
        infection = game.infections.find_by(city_staticid: los_angeles.staticid)
        expect(infection.quantity).to eq(1)
        expect(infection.color).to eq('blue')
      end

      it "places one blue infection marker in Tokyo" do
        command.call
        infection = game.infections.find_by(city_staticid: tokyo.staticid)
        expect(infection.quantity).to eq(1)
        expect(infection.color).to eq('blue')
      end

      it "places one blue infection marker in Chicago" do
        command.call
        infection = game.infections.find_by(city_staticid: chicago.staticid)
        expect(infection.quantity).to eq(1)
        expect(infection.color).to eq('blue')
      end

      it "places one red infection marker in Hong Kong" do
        command.call
        infection = game.infections.find_by(city_staticid: hong_kong.staticid)
        expect(infection.quantity).to eq(1)
        expect(infection.color).to eq('red')
      end

      it "places one red infection marker in Ho Chi Min City" do
        command.call
        infection = game.infections
          .find_by(city_staticid: ho_chi_min_city.staticid)
        expect(infection.quantity).to eq(1)
        expect(infection.color).to eq('red')
      end

      it "places one red infection marker in Taipei" do
        command.call
        infection = game.infections.find_by(city_staticid: taipei.staticid)
        expect(infection.quantity).to eq(1)
        expect(infection.color).to eq('red')
      end

      it "places one red infection marker in Sydney" do
        command.call
        infection = game.infections.find_by(city_staticid: sydney.staticid)
        expect(infection.quantity).to eq(1)
        expect(infection.color).to eq('red')
      end
    end

    context "when there is a triangle chain outbreak" do
      before(:each) do
        Fabricate(
          :infection,
          game: game,
          city_staticid: chicago.staticid,
          color: chicago.color,
          quantity: 3
        )
        Fabricate(
          :infection,
          game: game,
          city_staticid: los_angeles.staticid,
          color: los_angeles.color,
          quantity: 3
        )
      end

      it "triggers three outbreaks" do
        command.call
        expect(game.reload.outbreaks_nr).to eq(3)
      end

      it "places one blue infection marker in Montreal" do
        command.call
        infection = game.infections.find_by(city_staticid: montreal.staticid)
        expect(infection.quantity).to eq(1)
        expect(infection.color).to eq('blue')
      end

      it "places one blue infection marker in Atlanta" do
        command.call
        infection = game.infections.find_by(city_staticid: atlanta.staticid)
        expect(infection.quantity).to eq(1)
        expect(infection.color).to eq('blue')
      end

      it "places one blue infection marker in Mexico City" do
        command.call
        infection = game.infections
          .find_by(city_staticid: mexico_city.staticid, color: 'blue')
        expect(infection.quantity).to eq(1)
      end

      it "places one yellow infection marker in Mexico City" do
        command.call
        infection = game.infections
          .find_by(city_staticid: mexico_city.staticid, color: 'yellow')
        expect(infection.quantity).to eq(1)
      end

      it "places one yellow infection marker in Sydney" do
        command.call
        infection = game.infections.find_by(city_staticid: sydney.staticid)
        expect(infection.quantity).to eq(1)
        expect(infection.color).to eq('yellow')
      end

      it "places one blue infection marker in Manila" do
        command.call
        infection = game.infections.find_by(city_staticid: manila.staticid)
        expect(infection.quantity).to eq(1)
        expect(infection.color).to eq('blue')
      end

      it "places one blue infection marker in Tokyo" do
        command.call
        infection = game.infections.find_by(city_staticid: tokyo.staticid)
        expect(infection.quantity).to eq(1)
        expect(infection.color).to eq('blue')
      end
    end
  end
end
