# File original exported from 18xx-maker: https://www.18xx-maker.com/
# rubocop:disable Lint/RedundantCopDisableDirective, Layout/LineLength
# frozen_string_literal: true

require_relative '../config/game/g_1846'
require_relative '../g_1846/share_pool'
require_relative 'base'

module Engine
  module Game
    class G1846 < Base
      register_colors(red: '#d1232a',
                      orange: '#f58121',
                      black: '#110a0c',
                      blue: '#025aaa',
                      lightBlue: '#8dd7f6',
                      yellow: '#ffe600',
                      green: '#32763f')

      load_from_json(Config::Game::G1846::JSON)

      DEV_STAGE = :beta

      GAME_LOCATION = 'Midwest, USA'
      GAME_RULES_URL = 'https://s3-us-west-2.amazonaws.com/gmtwebsiteassets/1846/1846-RULES-GMT.pdf'
      GAME_DESIGNER = 'Thomas Lehmann'
      GAME_PUBLISHER = Publisher::INFO[:gmt_games]
      GAME_INFO_URL = 'https://github.com/tobymao/18xx/wiki/1846'

      POOL_SHARE_DROP = :one
      SELL_AFTER = :p_any_operate
      SELL_BUY_ORDER = :sell_buy
      SELL_MOVEMENT = :left_block_pres
      EBUY_OTHER_VALUE = false
      EBUY_DEPOT_TRAIN_MUST_BE_CHEAPEST = false
      HOME_TOKEN_TIMING = :float
      MUST_BUY_TRAIN = :always

      ORANGE_GROUP = [
        'Lake Shore Line',
        'Michigan Central',
        'Ohio & Indiana',
      ].freeze

      BLUE_GROUP = [
        'Steamboat Company',
        'Meat Packing Company',
        'Tunnel Blasting Company',
      ].freeze

      GREEN_GROUP = %w[C&O ERIE PRR].freeze

      TILE_COST = 20
      EVENTS_TEXT = Base::EVENTS_TEXT.merge('remove_tokens' => ['Remove Tokens', 'Remove private company tokens']).freeze

      ASSIGNMENT_TOKENS = {
        'MPC' => '/icons/1846/mpc_token.svg',
        'SC' => '/icons/1846/sc_token.svg',
      }.freeze

      # Two tiles can be laid, only one upgrade
      TILE_LAYS = [{ lay: true, upgrade: true }, { lay: true, upgrade: :not_if_upgraded }].freeze

      IPO_NAME = 'Treasury'

      def init_companies(players)
        super + @players.size.times.map do |i|
          name = "Pass (#{i + 1})"

          Company.new(
            sym: name,
            name: name,
            value: 0,
            desc: "Choose this card if you don't want to purchase any of the offered companies this round",
          )
        end
      end

      def init_share_pool
        Engine::G1846::SharePool.new(self)
      end

      def cert_limit
        num_corps = @corporations.size
        case @players.size
        when 3
          num_corps == 5 ? 14 : 11
        when 4
          case num_corps
          when 6
            12
          when 5
            10
          else
            8
          end
        when 5
          case num_corps
          when 7
            11
          when 6
            10
          when 5
            8
          else
            6
          end
        end
      end

      def michigan_southern
        @michigan_southern ||= minor_by_id('MS')
      end

      def big4
        @big4 ||= minor_by_id('BIG4')
      end

      def setup
        # When creating a game the game will not have enough to start
        return unless @players.size.between?(*Engine.player_range(self.class))

        remove_from_group!(ORANGE_GROUP, @companies) do |company|
          if company.id == 'LSL'
            %w[D14 E17].each do |hex|
              hex_by_id(hex).tile.icons.reject! { |icon| icon.name == 'lsl' }
            end
          end
          company.close!
          @round.active_step.companies.delete(company)
        end
        remove_from_group!(BLUE_GROUP, @companies) do |company|
          company.close!
          @round.active_step.companies.delete(company)
        end
        remove_from_group!(GREEN_GROUP, @corporations) do |corporation|
          place_home_token(corporation)
          corporation.abilities(:reservation) do |ability|
            corporation.remove_ability(ability)
          end
        end

        @companies.each do |company|
          company.min_price = 1
          company.max_price = company.value
        end

        @minors.each do |minor|
          train = @depot.upcoming[0]
          train.buyable = false
          minor.buy_train(train, :free)
          hex = hex_by_id(minor.coordinates)
          hex.tile.cities[0].place_token(minor, minor.next_token, free: true)
        end

        @last_action = nil
      end

      def remove_from_group!(group, entities)
        removals = group.sort_by { rand }.take([5 - @players.size, 2].min)
        # This looks verbose, but it works around the fact that we can't modify code which includes rand() w/o breaking existing games
        return if removals.empty?

        @log << "Removing #{removals.join(', ')}"
        entities.reject! do |entity|
          if removals.include?(entity.name)
            yield entity if block_given?
            true
          else
            false
          end
        end
      end

      def num_trains(train)
        num_players = @players.size

        case train[:name]
        when '2'
          num_players + 4
        when '4'
          num_players + 1
        when '5'
          num_players
        end
      end

      def revenue_for(route, stops)
        revenue = super

        east = stops.find { |stop| stop.groups.include?('E') }
        west = stops.find { |stop| stop.tile.label&.to_s == 'W' }

        meat = meat_packing.id

        revenue += 30 if route.corporation.assigned?(meat) && stops.any? { |stop| stop.hex.assigned?(meat) }

        steam = steamboat.id

        if route.corporation.assigned?(steam) && (port = stops.map(&:hex).find { |hex| hex.assigned?(steam) })
          revenue += 20 * port.tile.icons.select { |icon| icon.name == 'port' }.size
        end

        if east && west
          revenue += east.tile.icons.sum { |icon| icon.name.to_i }
          revenue += west.tile.icons.sum { |icon| icon.name.to_i }
        end

        if route.train.owner.companies.include?(mail_contract)
          longest = route.routes.max_by { |r| [r.visited_stops.size, r.train.id] }
          revenue += route.visited_stops.size * 10 if route == longest
        end

        revenue
      end

      def meat_packing
        @meat_packing ||= company_by_id('MPC')
      end

      def steamboat
        @steamboat ||= company_by_id('SC')
      end

      def michigan_central
        @michigan_central ||= company_by_id('MC')
      end

      def ohio_indiana
        @ohio_indiana ||= company_by_id('O&I')
      end

      def mail_contract
        @mail_contract ||= company_by_id('MAIL')
      end

      def illinois_central
        @illinois_central ||= corporation_by_id('IC')
      end

      def action_processed(action)
        case action
        when Action::Par
          if action.corporation == illinois_central
            bonus = action.share_price.price
            @bank.spend(bonus, illinois_central)
            @log << "#{illinois_central.name} receives a #{format_currency(bonus)} subsidy"
          end
        end

        check_special_tile_lay(action)

        @corporations.dup.each do |corporation|
          close_corporation(corporation) if corporation.share_price&.price&.zero?
        end

        @last_action = action
      end

      def special_tile_lay?(action)
        (action.is_a?(Action::LayTile) &&
         (action.entity == michigan_central || action.entity == ohio_indiana))
      end

      def check_special_tile_lay(action)
        company = @last_action&.entity
        return unless special_tile_lay?(@last_action)
        return unless (ability = company.abilities(:tile_lay))
        return if action.entity == company

        company.remove_ability(ability)
        @log << "#{company.name} forfeits second tile lay."
      end

      def close_corporation(corporation, quiet: false)
        @log << "#{corporation.name} closes" unless quiet

        hexes.each do |hex|
          hex.tile.cities.each do |city|
            if city.tokened_by?(corporation) || city.reserved_by?(corporation)
              city.tokens.map! { |token| token&.corporation == corporation ? nil : token }
              city.reservations.delete(corporation)
            end
          end
        end

        corporation.spend(corporation.cash, @bank) if corporation.cash.positive?
        corporation.trains.each { |t| t.buyable = false }
        if corporation.companies.any?
          @log << "#{corporation.name}'s companies close: #{corporation.companies.map(&:sym).join(', ')}"
          corporation.companies.dup.each(&:close!)
        end
        @round.force_next_entity! if @round.current_entity == corporation

        if corporation.corporation?
          corporation.share_holders.keys.each do |share_holder|
            share_holder.shares_by_corporation.delete(corporation)
          end

          @share_pool.shares_by_corporation.delete(corporation)
          corporation.share_price.corporations.delete(corporation)
          @corporations.delete(corporation)
        else
          @minors.delete(corporation)
        end
      end

      def init_round
        Round::Draft.new(self, [Step::G1846::DraftDistribution])
      end

      def priority_deal_player
        return @players.first if @round.is_a?(Round::Draft)

        super
      end

      def stock_round
        Round::Stock.new(self, [
          Step::DiscardTrain,
          Step::G1846::Assign,
          Step::G1846::BuySellParShares,
        ])
      end

      def operating_round(round_num)
        Round::G1846::Operating.new(self, [
          Step::G1846::Bankrupt,
          Step::DiscardTrain,
          Step::G1846::Assign,
          Step::SpecialToken,
          Step::SpecialTrack,
          Step::G1846::BuyCompany,
          Step::G1846::IssueShares,
          Step::G1846::TrackAndToken,
          Step::Route,
          Step::G1846::Dividend,
          Step::G1846::BuyTrain,
          [Step::G1846::BuyCompany, blocks: true],
        ], round_num: round_num)
      end

      def tile_cost(tile, entity)
        [TILE_COST, super].max
      end

      def event_close_companies!
        super

        @minors.dup.each { |minor| close_corporation(minor) }

        %w[D14 E17].each do |hex|
          hex_by_id(hex).tile.icons.reject! { |icon| icon.name == 'lsl' }
        end
      end

      def event_remove_tokens!
        removals = Hash.new { |h, k| h[k] = {} }

        @corporations.each do |corp|
          corp.assignments.dup.each do |company, _|
            removals[company][:corporation] = corp.name
            corp.remove_assignment!(company)
          end
        end

        @hexes.each do |hex|
          hex.assignments.dup.each do |company, _|
            removals[company][:hex] = hex.name
            hex.remove_assignment!(company)
          end
        end

        %w[B8 C5 D6 D14 G19 I1].each do |hex|
          hex_by_id(hex).tile.icons.reject! do |icon|
            %w[meat port].include?(icon.name)
          end
        end

        removals.each do |company, removal|
          hex = removal[:hex]
          corp = removal[:corporation]
          @log << "-- Event: #{corp}'s #{company_by_id(company).name} token removed from #{hex} --"
        end
      end

      def bankruptcy_limit_reached?
        @players.reject(&:bankrupt).one?
      end

      def sellable_bundles(player, corporation)
        return [] if corporation.receivership?

        super
      end

      def emergency_issuable_bundles(corp)
        return [] if @round.emergency_issued

        min_train_price, max_train_price = @depot.min_depot_train.variants.map { |_, v| v[:price] }.minmax
        return [] if corp.cash >= max_train_price

        bundles = corp.bundles_for_corporation(corp)

        num_issuable_shares = corp.num_player_shares - corp.num_market_shares
        bundles.reject! { |bundle| bundle.num_shares > num_issuable_shares }

        bundles.each do |bundle|
          directions = [:left] * (1 + bundle.num_shares)
          bundle.share_price = stock_market.find_share_price(corp, directions).price
        end

        # cannot issue shares that generate no money; this is errata from BGG
        # and differs from the GMT rulebook
        # https://boardgamegeek.com/thread/2094996/article/30495755#30495755
        bundles.reject! { |b| b.price.zero? }

        bundles.sort_by!(&:price)

        # Cannot issue more shares than needed to buy the train from the bank
        # (but may buy either variant)
        # https://boardgamegeek.com/thread/1849992/article/26952925#26952925
        train_buying_bundles = bundles.select { |b| (corp.cash + b.price) >= min_train_price }
        if train_buying_bundles.any?
          bundles = train_buying_bundles

          index = bundles.find_index { |b| (corp.cash + b.price) >= max_train_price }
          return bundles.take(index + 1) if index

          return bundles
        end

        # if a train cannot be afforded, issue all possible shares
        # https://boardgamegeek.com/thread/1849992/article/26939192#26939192
        biggest_bundle = bundles.max_by(&:num_shares)
        return [biggest_bundle] if biggest_bundle

        []
      end

      def bundle_is_presidents_share_alone_in_pool?(bundle)
        return unless bundle

        bundle = bundle.to_bundle

        bundle.corporation.receivership? &&
          bundle.presidents_share &&
          bundle.shares.one? &&
          @share_pool.shares_of(bundle.corporation).one?
      end
    end
  end
end

# rubocop:enable Lint/RedundantCopDisableDirective, Layout/LineLength
