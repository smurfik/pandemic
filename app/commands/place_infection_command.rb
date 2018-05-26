class PlaceInfectionCommand
  prepend SimpleCommand

  def initialize(game:, staticid:, quantity:, color: nil, outbreakids: [])
    @game = game
    @staticid = staticid
    @quantity = quantity
    @color = color || city.color
    @outbreakids = outbreakids
  end

  def call
    set_before_quantity
    infection.update!(quantity: quantities.min)
    trigger_outbreak if outbreak?
  end

  private

  def trigger_outbreak
    @outbreakids << @staticid
    @game.increment!(:outbreaks_nr)
    city.neighbors.each do |neighbor|
      next if @outbreakids.include?(neighbor.staticid)
      PlaceInfectionCommand.new(
        game: @game,
        staticid: neighbor.staticid,
        quantity: 1,
        color: city.color,
        outbreakids: @outbreakids
      ).call
    end
  end

  def infection
    @infection ||= @game.infections
      .find_or_create_by!(color: @color, city_staticid: @staticid)
  end

  def total_quantity
    @total_quantity ||= infection.quantity + @quantity
  end

  def ceiled_quantity
    quantities.min
  end

  def city
    @city ||= City.find(@staticid)
  end

  def other_infections_total_quantity
    @other_infections_total_quantity ||= @game.infections
      .where(city_staticid: @staticid)
      .where.not(color: @color)
      .total_quantity
  end

  def quantities
    [total_quantity, 3 - other_infections_total_quantity]
  end

  def set_before_quantity
    @before_quantity ||= @game.infections
      .where(city_staticid: @staticid)
      .total_quantity
  end

  def outbreak?
    @before_quantity + @quantity > 3
  end
end
