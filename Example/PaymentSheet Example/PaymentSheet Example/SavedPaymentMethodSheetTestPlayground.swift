//
//  SavedPaymentMethodSheetTestPlayground.swift
//  PaymentSheet Example
//
//  ⚠️🏗 This is a playground for internal Stripe engineers to help us test things, and isn't
//  an example of what you should do in a real app!
//  Note: Do not import Stripe using `@_spi(STP)` or @_spi(PrivateBetaSavedPaymentMethodsSheet) in production.
//  This exposes internal functionality which may cause unexpected behavior if used directly.

import Contacts
import Foundation
import PassKit
@_spi(PrivateBetaSavedPaymentMethodsSheet) import StripePaymentSheet
@_spi(PrivateBetaSavedPaymentMethodsSheet) import StripePaymentsUI
import SwiftUI
import UIKit

class SavedPaymentMethodSheetTestPlayground: UIViewController {
    static let defaultSavedPaymentMethodEndpoint = "https://stp-mobile-ci-test-backend-v7.stripedemos.com"
    static var paymentSheetPlaygroundSettings: SavedPaymentMethodSheetPlaygroundSettings?

    @IBOutlet weak var customerModeSelector: UISegmentedControl!

    @IBOutlet weak var pmModeSelector: UISegmentedControl!
    @IBOutlet weak var applePaySelector: UISegmentedControl!
    @IBOutlet weak var headerTextForSelectionScreenTextField: UITextField!

    @IBOutlet weak var loadButton: UIButton!

    @IBOutlet weak var selectPaymentMethodButton: UIButton!
    @IBOutlet weak var selectPaymentMethodImage: UIImageView!

    var savedPaymentMethodsSheet: SavedPaymentMethodsSheet?
    var paymentOptionSelection: SavedPaymentMethodsSheet.PaymentOptionSelection?

    enum CustomerMode: String, CaseIterable {
        case new
        case returning
    }

    enum PaymentMethodMode {
        case setupIntent
        case createAndAttach
    }

    var customerMode: CustomerMode {
        switch customerModeSelector.selectedSegmentIndex {
        case 0:
            return .new
        default:
            return .returning
        }
    }

    var paymentMethodMode: PaymentMethodMode {
        switch pmModeSelector.selectedSegmentIndex {
        case 0:
            return .setupIntent
        default:
            return .createAndAttach
        }
    }

    var backend: SavedPaymentMethodsBackend!

    var ephemeralKey: String?
    var customerId: String?
    var customerContext: _stpspmsbeta_STPCustomerContext?
    var savedPaymentMethodEndpoint: String = defaultSavedPaymentMethodEndpoint
    var appearance = PaymentSheet.Appearance.default

    func makeAlertController() -> UIAlertController {
        let alertController = UIAlertController(
            title: "Complete", message: "Completed", preferredStyle: .alert)
        let OKAction = UIAlertAction(title: "OK", style: .default) { (_) in
            alertController.dismiss(animated: true, completion: nil)
        }
        alertController.addAction(OKAction)
        return alertController
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        loadButton.addTarget(self, action: #selector(load), for: .touchUpInside)
        selectPaymentMethodButton.isEnabled = false
        selectPaymentMethodButton.addTarget(
            self, action: #selector(didTapSelectPaymentMethodButton), for: .touchUpInside)

        if let paymentSheetPlaygroundSettings = SavedPaymentMethodSheetTestPlayground.paymentSheetPlaygroundSettings {
            loadSettingsFrom(settings: paymentSheetPlaygroundSettings)
        } else if let nsUserDefaultSettings = settingsFromDefaults() {
            loadSettingsFrom(settings: nsUserDefaultSettings)
            loadBackend()
        }
    }
    @objc
    func didTapSelectPaymentMethodButton() {
        savedPaymentMethodsSheet?.present(from: self)
    }

    func updateButtons() {
        // Update the payment method selection button
        if let paymentOption = self.paymentOptionSelection {
            self.selectPaymentMethodButton.setTitle(paymentOption.displayData().label, for: .normal)
            self.selectPaymentMethodButton.setTitleColor(.label, for: .normal)
            self.selectPaymentMethodImage.image = paymentOption.displayData().image
        } else {
            self.selectPaymentMethodButton.setTitle("Select", for: .normal)
            self.selectPaymentMethodButton.setTitleColor(.systemBlue, for: .normal)
            self.selectPaymentMethodImage.image = nil
        }
        self.selectPaymentMethodButton.setNeedsLayout()
    }

    @IBAction func didTapEndpointConfiguration(_ sender: Any) {
        // TODO
//        let endpointSelector = EndpointSelectorViewController(delegate: self,
//                                                              endpointSelectorEndpoint: Self.endpointSelectorEndpoint,
//                                                              currentCheckoutEndpoint: )
//        let navController = UINavigationController(rootViewController: endpointSelector)
//        self.navigationController?.present(navController, animated: true, completion: nil)
    }

    @IBAction func didTapResetConfig(_ sender: Any) {
        loadSettingsFrom(settings: SavedPaymentMethodSheetPlaygroundSettings.defaultValues())
    }

    @IBAction func appearanceButtonTapped(_ sender: Any) {
        if #available(iOS 14.0, *) {
            let vc = UIHostingController(rootView: AppearancePlaygroundView(appearance: appearance, doneAction: { updatedAppearance in
                self.appearance = updatedAppearance
                self.dismiss(animated: true, completion: nil)
            }))

            self.navigationController?.present(vc, animated: true, completion: nil)
        } else {
            let alert = UIAlertController(title: "Unavailable", message: "Appearance playground is only available in iOS 14+.", preferredStyle: UIAlertController.Style.alert)
            alert.addAction(UIAlertAction(title: "Ok", style: UIAlertAction.Style.default, handler: nil))
            self.present(alert, animated: true, completion: nil)
        }
    }

    func savedPaymentMethodSheetConfiguration(customerId: String, ephemeralKey: String) -> SavedPaymentMethodsSheet.Configuration {
        let customerContext = _stpspmsbeta_STPCustomerContext(customerId: customerId, ephemeralKeySecret: ephemeralKey)
        self.customerContext = customerContext
        var configuration = SavedPaymentMethodsSheet.Configuration(customerContext: customerContext,
                                                                   applePayEnabled: applePayEnabled())
        configuration.createSetupIntentHandler = setupIntentHandler(customerId: customerId)
        configuration.appearance = appearance
        configuration.returnURL = "payments-example://stripe-redirect"
        configuration.headerTextForSelectionScreen = headerTextForSelectionScreenTextField.text

        return configuration
    }
    func setupIntentHandler(customerId: String) -> SavedPaymentMethodsSheet.Configuration.CreateSetupIntentHandlerCallback? {
        switch paymentMethodMode {
        case .setupIntent:
            return { completionBlock in
                self.backend.createSetupIntent(customerId: customerId,
                                               completion: completionBlock)
            }
        case .createAndAttach:
            return nil
        }
    }
    func applePayEnabled() -> Bool {
        switch applePaySelector.selectedSegmentIndex {
        case 0:
            return true
        default:
            return false
        }
    }
}

// MARK: - Backend

extension SavedPaymentMethodSheetTestPlayground {
    @objc
    func load() {
        serializeSettingsToNSUserDefaults()
        loadBackend()
    }
    func loadBackend() {
        selectPaymentMethodButton.isEnabled = false
        savedPaymentMethodsSheet = nil
        paymentOptionSelection = nil

        let customerType = customerMode == .new ? "new" : "returning"
        self.backend = SavedPaymentMethodsBackend(endpoint: savedPaymentMethodEndpoint)

        self.backend.loadBackendCustomerEphemeralKey(customerType: customerType) { result in
            guard let json = result,
                  let ephemeralKey = json["customerEphemeralKeySecret"], !ephemeralKey.isEmpty,
                  let customerId = json["customerId"], !customerId.isEmpty,
                  let publishableKey = json["publishableKey"] else {
                return
            }
            self.ephemeralKey = ephemeralKey
            self.customerId = customerId
            StripeAPI.defaultPublishableKey = publishableKey

            DispatchQueue.main.async {
                let configuration = self.savedPaymentMethodSheetConfiguration(customerId: customerId, ephemeralKey: ephemeralKey)
                self.savedPaymentMethodsSheet = SavedPaymentMethodsSheet(configuration: configuration, delegate: self)

                self.selectPaymentMethodButton.isEnabled = true

                self.customerContext?.retrievePaymentOptionSelection { selection, _ in
                    self.paymentOptionSelection = selection
                    self.updateButtons()
                }
            }
        }
    }
}

extension SavedPaymentMethodSheetTestPlayground: SavedPaymentMethodsSheetDelegate {
    func didFinish(with paymentOptionSelection: SavedPaymentMethodsSheet.PaymentOptionSelection?) {
        self.paymentOptionSelection = paymentOptionSelection
        self.updateButtons()
        let alertController = self.makeAlertController()
        if let paymentOptionSelection = paymentOptionSelection {
            alertController.message = "Success: \(paymentOptionSelection.displayData().label)"
        } else {
            alertController.message = "Success: payment method unset"
        }
        self.present(alertController, animated: true) {
            self.load()
        }

    }

    func didCancel() {
        self.updateButtons()
        let alertController = self.makeAlertController()
        alertController.message = "Canceled"
        self.present(alertController, animated: true) {
            self.load()
        }
    }

    func didFail(with error: SavedPaymentMethodsSheetError) {
        switch error {
        case .setupIntentClientSecretInvalid:
            print("Intent invalid...")
        case .errorFetchingSavedPaymentMethods(let error):
            print("saved payment methods errored:\(error)")
        case .setupIntentFetchError(let error):
            print("fetching si errored: \(error)")
        default:
            print("something went wrong: \(error)")
        }
    }
}

struct SavedPaymentMethodSheetPlaygroundSettings: Codable {
    static let nsUserDefaultsKey = "savedPaymentMethodPlaygroundSettings"

    let customerModeSelectorValue: Int
    let paymentMethodModeSelectorValue: Int
    let applePaySelectorSelectorValue: Int
    let selectingSavedCustomHeaderText: String?
    let savedPaymentMethodEndpoint: String?

    static func defaultValues() -> SavedPaymentMethodSheetPlaygroundSettings {
        return SavedPaymentMethodSheetPlaygroundSettings(
            customerModeSelectorValue: 0,
            paymentMethodModeSelectorValue: 0,
            applePaySelectorSelectorValue: 0,
            selectingSavedCustomHeaderText: nil,
            savedPaymentMethodEndpoint: SavedPaymentMethodSheetTestPlayground.defaultSavedPaymentMethodEndpoint
        )
    }
}

// MARK: - EndpointSelectorViewControllerDelegate
extension SavedPaymentMethodSheetTestPlayground: EndpointSelectorViewControllerDelegate {
    func selected(endpoint: String) {
        savedPaymentMethodEndpoint = endpoint
        serializeSettingsToNSUserDefaults()
        loadBackend()
        self.navigationController?.dismiss(animated: true)

    }
    func cancelTapped() {
        self.navigationController?.dismiss(animated: true)
    }
}

// MARK: - Helpers

extension SavedPaymentMethodSheetTestPlayground {
    func serializeSettingsToNSUserDefaults() {
        let settings = SavedPaymentMethodSheetPlaygroundSettings(
            customerModeSelectorValue: customerModeSelector.selectedSegmentIndex,
            paymentMethodModeSelectorValue: pmModeSelector.selectedSegmentIndex,
            applePaySelectorSelectorValue: applePaySelector.selectedSegmentIndex,
            selectingSavedCustomHeaderText: headerTextForSelectionScreenTextField.text,
            savedPaymentMethodEndpoint: savedPaymentMethodEndpoint
        )
        let data = try! JSONEncoder().encode(settings)
        UserDefaults.standard.set(data, forKey: SavedPaymentMethodSheetPlaygroundSettings.nsUserDefaultsKey)
    }

    func settingsFromDefaults() -> SavedPaymentMethodSheetPlaygroundSettings? {
        if let data = UserDefaults.standard.value(forKey: SavedPaymentMethodSheetPlaygroundSettings.nsUserDefaultsKey) as? Data {
            do {
                return try JSONDecoder().decode(SavedPaymentMethodSheetPlaygroundSettings.self, from: data)
            } catch {
                print("Unable to deserialize saved settings")
                UserDefaults.standard.removeObject(forKey: SavedPaymentMethodSheetPlaygroundSettings.nsUserDefaultsKey)
            }
        }
        return nil
    }

    func loadSettingsFrom(settings: SavedPaymentMethodSheetPlaygroundSettings) {
        customerModeSelector.selectedSegmentIndex = settings.customerModeSelectorValue
        pmModeSelector.selectedSegmentIndex = settings.paymentMethodModeSelectorValue
        applePaySelector.selectedSegmentIndex = settings.applePaySelectorSelectorValue
        headerTextForSelectionScreenTextField.text = settings.selectingSavedCustomHeaderText
        savedPaymentMethodEndpoint = settings.savedPaymentMethodEndpoint ?? SavedPaymentMethodSheetTestPlayground.defaultSavedPaymentMethodEndpoint
    }
}

class SavedPaymentMethodsBackend {

    let endpoint: String
    var clientSecret: String?
    public init(endpoint: String) {
        self.endpoint = endpoint
    }

    func loadBackendCustomerEphemeralKey(customerType: String, completion: @escaping ([String: String]?) -> Void) {

        let body = [ "customer_type": customerType
        ] as [String: Any]

        let url = URL(string: "\(endpoint)/customer_ephemeral_key")!
        let session = URLSession.shared

        let json = try! JSONSerialization.data(withJSONObject: body, options: [])
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.httpBody = json
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-type")
        let task = session.dataTask(with: urlRequest) { data, _, error in
            guard
                error == nil,
                let data = data,
                let json = try? JSONDecoder().decode([String: String].self, from: data) else {
                print(error as Any)
                completion(nil)
                return
            }
            completion(json)
        }
        task.resume()
    }

    func createSetupIntent(customerId: String, completion: @escaping (String?) -> Void) {
        guard clientSecret == nil else {
            completion(clientSecret)
            return
        }
        let body = [ "customer_id": customerId,
        ] as [String: Any]
        let url = URL(string: "\(endpoint)/create_setup_intent")!
        let session = URLSession.shared

        let json = try! JSONSerialization.data(withJSONObject: body, options: [])
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.httpBody = json
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-type")
        let task = session.dataTask(with: urlRequest) { data, _, error in
            guard
                error == nil,
                let data = data,
                let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
                print(error as Any)
                completion(nil)
                return
            }
            guard let secret = json["client_secret"] as? String else {
                completion(nil)
                return
            }
            self.clientSecret = secret
            completion(secret)
        }
        task.resume()
    }
}
