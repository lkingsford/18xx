# frozen_string_literal: true

require 'lib/settings'

module View
  module Game
    class Bank < Snabberb::Component
      include Lib::Settings

      needs :game
      needs :layout, default: nil

      def render
        if @layout == :card
          render_card
        else
          props = {
            style: {
              marginBottom: '1rem',
            },
          }
          h(:div, props, "Bank Cash: #{@game.format_currency(@game.bank.cash)}")
        end
      end

      def render_card
        title_props = {
          style: {
            padding: '0.4rem',
            backgroundColor: color_for(:bg2),
            color: color_for(:font2),
          },
        }
        body_props = {
          style: {
            margin: '0.3rem 0.5rem 0.4rem',
            display: 'grid',
            grid: 'auto / 1fr',
            gap: '0.5rem',
            justifyItems: 'center',
          },
        }

        trs = []
        if @game.class::GAME_END_CHECK.include?(:bank)
          trs << h(:tr, [
            h(:td, 'Cash'),
            h('td.right', @game.format_currency(@game.bank.cash)),
          ])
        end
        if (rate = @game.interest_rate)
          trs << h(:tr, [
            h(:td, 'Interest per Loan'),
            h('td.right', @game.format_currency(rate)),
          ])
          trs << h(:tr, [
            h(:td, 'Loans'),
            h('td.right', "#{@game.loans_taken}/#{@game.total_loans}"),
          ])
          trs << h(:tr, [
            h(:td, 'Loan Value'),
            h('td.right', @game.format_currency(@game.loan_value)),
          ])
        end

        h('div.bank.card', [
          h('div.title.nowrap', title_props, [h(:em, 'The Bank')]),
          h(:div, body_props, [
            h(:table, trs),
            h(GameInfo, game: @game, layout: 'discarded_trains'),
          ]),
        ])
      end
    end
  end
end
