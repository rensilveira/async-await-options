import Foundation
import PlaygroundSupport
import SwiftUI

// MARK: - View layer

struct MyDummyViewState {
  var rate: String
}

struct MyDummyView<T>: View where T: MyDummyViewModel {

  @StateObject var viewModel: T

  var body: some View {
    Text(viewModel.viewState.rate)
      .onAppear {

        // Option 1
        Task {
          await viewModel.onAppear()
        }
      }
  }
}

// MARK: - ViewModel layer

protocol MyDummyViewModel: ObservableObject {
  var viewState: MyDummyViewState { get set }

  func onAppear() async
}

final class MyDummyViewModelImpl: MyDummyViewModel {

  init(interactor: DummyInteractor) {
    self.interactor = interactor
    self.viewState = .init(rate: "")

    bindInteractor()
  }

  @Published var viewState: MyDummyViewState

  func onAppear() async {
    await interactor.getBitcoinRate()
  }

  private func bindInteractor() {
    interactor.onReceivedRate = { [weak self] in
      self?.handleRateFetch($0)
    }
  }

  private func handleRateFetch(_ rate: String?) {
    viewState.rate = rate ?? ""
  }

  private var interactor: DummyInteractor
}

// MARK: - Interactor layer

protocol DummyInteractor {
  // Output
  typealias RateResultHandler = (String?) -> Void
  var onReceivedRate: RateResultHandler? { get set }

  // Input
  func getBitcoinRate() async
}

final class DummyInteractorImpl: DummyInteractor {

  init(service: DummyService) {
    self.service = service
  }

  var onReceivedRate: RateResultHandler?

  private let service: DummyService

  func getBitcoinRate() async {
    let task = Task {
      try? await service.getBitcoinRate()
    }

    switch await task.result {
    case .success(let rate):
      onReceivedRate?(rate)
    case .failure:
      // handle error
      onReceivedRate?(nil)
    }
  }
}

// MARK: - Service layer

protocol DummyService {
  func getBitcoinRate() async throws -> String
}

final class DummyServiceImpl: DummyService {

  enum DummyServiceError: Error {
    case invalidURL
    case fetchError
    case invalidResponse
  }

  func getBitcoinRate() async throws -> String {
    guard let url = Constants.url else { throw DummyServiceError.invalidURL }

    let urlRequest = URLRequest(url: url)
    let (data, response) = try await URLSession.shared.data(for: urlRequest)

    guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw DummyServiceError.fetchError }

    let decodedResponse = try JSONDecoder().decode(DefaultResponse.self, from: data)
    guard let audRate = decodedResponse.data.rates[Constants.audCurrency] else { throw DummyServiceError.invalidResponse }

    print("BTC rates in AUD:", audRate)
    return audRate
  }

  private struct Constants {
    static let url = URL(string: "https://api.coinbase.com/v2/exchange-rates?currency=BTC")
    static let audCurrency = "AUD"
  }
}

// MARK: - Model layer

struct DefaultResponse: Codable {
    let data: DataClass
}

struct DataClass: Codable {
    let currency: String
    let rates: [String: String]
}

// MARK: - Playground rendering

let service = DummyServiceImpl()
let interactor = DummyInteractorImpl(service: service)
let viewModel = MyDummyViewModelImpl(interactor: interactor)
let dummyView = MyDummyView(viewModel: viewModel)

PlaygroundPage.current.setLiveView(
  dummyView
    .frame(width: 500.0, height: 500.0)
)
