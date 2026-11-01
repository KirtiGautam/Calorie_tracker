import Foundation
import Testing
@testable import CalTracker

/// Sign-in, sign-out and deletion start a sync without awaiting it, so tests that trigger one
/// await `device.sync()` before ending. Otherwise the pass outlives the test's in-memory container.
struct AccountViewModelTests {
    private let server = FakeGramwiseAPI()

    private func makeViewModel(tokens: GramwiseTokenPair? = nil) -> (AccountViewModel, SyncTestDevice) {
        let device = SyncTestDevice(server: server, tokens: tokens)
        return (AccountViewModel(account: device.account, sync: device.engine), device)
    }

    @Test func aShortPasswordIsRejectedBeforeAnyRequest() async {
        let (viewModel, _) = makeViewModel()
        viewModel.email = "ada@example.com"
        viewModel.password = "short"

        await viewModel.submit()

        #expect(viewModel.errorMessage == .errorPasswordTooShort)
        #expect(server.calls.isEmpty)
    }

    @Test func creatingAnAccountSignsInAndClearsThePassword() async {
        let (viewModel, device) = makeViewModel()
        viewModel.email = "  Ada@Example.com "
        viewModel.password = "correct horse"

        await viewModel.submit()

        #expect(viewModel.signedInEmail == "ada@example.com")
        #expect(viewModel.password.isEmpty)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.isWorking == false)
        await device.sync()
        #expect(viewModel.syncStatus == .upToDate(Date(timeIntervalSince1970: 1_800_000_000)))
    }

    @Test func aTakenEmailShowsAMessage() async throws {
        _ = try await server.signUp(email: "ada@example.com", password: "correct horse")
        let (viewModel, _) = makeViewModel()
        viewModel.email = "ada@example.com"
        viewModel.password = "another password"

        await viewModel.submit()

        #expect(viewModel.errorMessage == .errorEmailTaken)
        #expect(viewModel.signedInEmail == nil)
    }

    @Test func signingInWithAWrongPasswordShowsAMessage() async throws {
        _ = try await server.signUp(email: "ada@example.com", password: "correct horse")
        let (viewModel, _) = makeViewModel()
        viewModel.mode = .signIn
        viewModel.email = "ada@example.com"
        viewModel.password = "wrong"

        await viewModel.submit()

        #expect(viewModel.errorMessage == .errorInvalidCredentials)
    }

    @Test func signingInAcceptsAShortExistingPassword() async throws {
        _ = try await server.signUp(email: "ada@example.com", password: "short")
        let (viewModel, device) = makeViewModel()
        viewModel.mode = .signIn
        viewModel.email = "ada@example.com"
        viewModel.password = "short"

        await viewModel.submit()
        await device.sync()

        #expect(viewModel.signedInEmail == "ada@example.com")
    }

    @Test func cannotSubmitAnEmptyForm() {
        let (viewModel, _) = makeViewModel()
        viewModel.email = "   "
        viewModel.password = "correct horse"

        #expect(viewModel.canSubmit == false)
    }

    @Test func signingOutKeepsTheLog() async throws {
        let tokens = try await server.signUp(email: "ada@example.com", password: "correct horse")
        let (viewModel, device) = makeViewModel(tokens: tokens)
        try device.store.log(.fixture(), grams: 100, loggedAt: .now)

        viewModel.signOut()
        await device.sync()

        #expect(viewModel.signedInEmail == nil)
        #expect(viewModel.syncStatus == .signedOut)
        #expect(try device.entries().count == 1)
    }

    @Test func deletingTheAccountRemovesItFromTheServer() async throws {
        let tokens = try await server.signUp(email: "ada@example.com", password: "correct horse")
        let (viewModel, device) = makeViewModel(tokens: tokens)

        await viewModel.deleteAccount()
        await device.sync()

        #expect(viewModel.signedInEmail == nil)
        #expect(server.hasAccount(email: "ada@example.com") == false)
    }

    @Test func aFailedDeletionShowsAMessageAndStaysSignedIn() async throws {
        let tokens = try await server.signUp(email: "ada@example.com", password: "correct horse")
        let (viewModel, device) = makeViewModel(tokens: tokens)
        server.fail(with: GramwiseAPIError.unreachable)

        await viewModel.deleteAccount()
        await device.sync()

        #expect(viewModel.errorMessage == .errorSyncServer)
        #expect(viewModel.signedInEmail == "ada@example.com")
    }
}
