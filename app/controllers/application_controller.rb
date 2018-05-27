require "application_responder"

class ApplicationController < ActionController::API
  self.responder = ApplicationResponder
  respond_to :json
  helper_method :game

  before_action :authenticate_request
  attr_reader :current_user

  private

  def authenticate_request
    @current_user = AuthorizeApiRequest.call(request.headers).result
    render json: { error: 'Not Authorized' }, status: 401 unless @current_user
  end

  def game
    @game ||= current_user.games.find_by(id: params[:game_id])
  end

  def current_player
    @current_player ||= current_user.players.find_by(game: game)
  end

  def active_player_id
    GetActivePlayer.new(
      player_ids: game.player_turn_ids,
      turn_nr: game.turn_nr
    ).call.result
  end

  def active_player
    @active_player ||= game.players.find_by(id: active_player_id)
  end

  def check_for_potential_create_errors
    render json: { error: create_error_message } if create_error_message
  end

  def check_for_potential_update_errors
    render json: { error: update_error_message } if update_error_message
  end
end
