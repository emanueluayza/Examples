//
//  ViewController.swift
//  CleanUI
//
//  Created by Emanuel Luayza on 14/09/2020.
//  Copyright © 2020 Blaztt. All rights reserved.
//

import UIKit
import Anchorage
import Then

struct CardInfo {
    var cardHolder: String
    var balance: Double
    var number: String
    var expires: String
}

class ViewController: UIViewController {

    // MARK: - Properties

    let topCard = CardInfo(cardHolder: "EMA LUAYZA", balance: 5000, number: "4276 5842 1292 1200", expires: "09/21")
    let midCard = CardInfo(cardHolder: "MARIANO URBINA", balance: 0, number: "0292 3950 8394 9192", expires: "04/25")
    let bottomCard = CardInfo(cardHolder: "EZE EXCOFFON", balance: 2401, number: "7820 8572 0199 8133", expires: "01/22")

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCreditCardUI()
    }

    // MARK: - Setups

    func setupCreditCardUI() {
        view.layoutMargins = UIEdgeInsets(inset: 16)

        let scrollView = UIScrollView()

        view.addSubview(scrollView)

        scrollView.edgeAnchors == view.layoutMarginsGuide.edgeAnchors

        let cardsStackView = UIStackView(axis: .vertical, arrangedSubviews: [
            createCard(with: topCard, and: .cardGreyBackgroundColor),
            createCard(with: midCard, and: .cardRedBackgroundColor),
            createCard(with: bottomCard, and: .cardLilaBackgroundColor)
        ]).then {
            $0.spacing = 16
        }

        scrollView.addSubview(cardsStackView)

        cardsStackView.edgeAnchors == scrollView.edgeAnchors
        cardsStackView.widthAnchor == scrollView.widthAnchor
    }

    func createCard(with info: CardInfo, and color: UIColor) -> UIView {
        let cardView = UIView().then {
            $0.backgroundColor = color
            $0.cornerRadius = 10
            $0.layoutMargins = UIEdgeInsets(inset: 16)
        }

        let cardStackView = UIStackView(axis: .vertical, arrangedSubviews: [
            UIStackView(axis: .horizontal, arrangedSubviews: [
                UIImageView(image: UIImage(named: "visa-logo")).then {
                    $0.contentMode = .scaleAspectFit
                    $0.clipsToBounds = true
                    $0.widthAnchor == 60
                },
                createLabel(with: "Balance", color: .cardLabelColor, font: .systemFont(ofSize: 14), and: .right),
                createLabel(with: " $\(info.balance)", color: .white, font: .boldSystemFont(ofSize: 14), and: .right)
            ]).then {
                $0.distribution = .fill
            },
            UILabel().then {
                $0.text = info.number
                $0.textAlignment = .center
                $0.font = UIFont.systemFont(ofSize: 24)
            },
            UIStackView(axis: .horizontal, arrangedSubviews: [
                UIStackView(axis: .vertical, arrangedSubviews: [
                    createLabel(with: "CARD HOLDER", color: .cardLabelColor, font: .systemFont(ofSize: 14), and: .left),
                    createLabel(with: info.cardHolder, color: .white, font: .boldSystemFont(ofSize: 14), and: .left)
                ]).then {
                    $0.spacing = 8
                    $0.alignment = .leading
                },
                UIStackView(axis: .vertical, arrangedSubviews: [
                    createLabel(with: "EXPIRES", color: .cardLabelColor, font: .systemFont(ofSize: 14), and: .right),
                    createLabel(with: info.expires, color: .white, font: .boldSystemFont(ofSize: 14), and: .right)
                ]).then {
                    $0.spacing = 8
                    $0.alignment = .trailing
                }
            ])
        ]).then {
            $0.spacing = 20
        }

        cardView.addSubview(cardStackView)

        cardStackView.edgeAnchors == cardView.layoutMarginsGuide.edgeAnchors

        view.layoutIfNeeded()

        return cardView
    }

    func createLabel(with text: String,
                     color: UIColor,
                     font: UIFont,
                     and aligment: NSTextAlignment) -> UILabel {
        return UILabel().then {
            $0.text = text
            $0.textColor = color
            $0.font = font
            $0.textAlignment = aligment
        }
    }
}
