import Foundation
import Testing
@testable import AMSA

/// Shapes follow the route handlers in reference-amsa-website/src/app/api (synthetic data, no real users).
@Suite("Model decoding")
struct DecodingTests {
    @Test func collegeToleratesNullsWithServerDefaults() throws {
        let c = try Fixture.decode(College.self, """
        {"id": 1, "name": "Null U", "state": null, "type": null, "tuition": null, "majorCategories": null,
         "meritScholarships": null, "financialAccessibilityScore": null, "somethingNew": {"nested": true}}
        """)
        #expect(c.type == "private")
        #expect(c.tuition == 0)
        #expect(c.booksAndSupplies == 1000)
        #expect(c.personalExpenses == 2000)
        #expect(c.healthInsurance == 3000)
        #expect(c.majorCategories.isEmpty)
        #expect(c.meritScholarships.isEmpty)
        #expect(c.stateAbbr.isEmpty)
    }

    @Test func journalSchemaMatchesTheWeb() throws {
        var journal = JournalData()
        journal.rowOrder = [3, 1]
        journal.customColumns = [.init(id: "col_1", name: "Deadline")]
        journal.customData = ["col_1": ["3": "Jan 1"]]
        journal.statusData = ["3": "applying"]
        let object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(journal)) as? [String: Any])
        #expect(Set(object.keys) == ["rowOrder", "customColumns", "customData", "statusData", "notesData"])
        #expect(try JSONDecoder().decode(JournalData.self, from: JSONEncoder().encode(journal)) == journal)
    }

    @Test func journalAcceptsAnyObjectWithRowOrder() throws {
        // `loadJournal` returns the parsed object whenever `rowOrder` is an array.
        let partial = try Fixture.decode(JournalData.self, #"{"rowOrder": [5], "statusData": {"5": "applied"}}"#)
        #expect(partial.rowOrder == [5])
        #expect(partial.statusData == ["5": "applied"])
        #expect(partial.customColumns.isEmpty)
        #expect(throws: (any Error).self) { try Fixture.decode(JournalData.self, #"{"customColumns": []}"#) }
    }

    @Test func verificationSubmission() throws {
        let s = try Fixture.decode(VerificationSubmission.self, """
        {"id": "b6c1", "userId": 9, "createdAt": "2026-09-01T10:00:00.000Z", "fullName": "Test Person",
         "pronouns": null, "enrolledUniversity": "Test University", "yearInSchool": "Junior", "state": "CA",
         "city": "Davis", "major": "CS", "expectedGraduation": 2027, "email": "t@test.edu", "socialMedia": "@t",
         "phone": 5550100, "careerInterests": ["Tech"], "careerInterestsOther": null, "amsaInterests": [],
         "amsaInterestsOther": "Mentoring", "mentorshipInterest": "Yes", "eventIdeas": null,
         "heardAboutAmsa": "Friend", "heardAboutAmsaOther": null, "agreesToEmails": true,
         "reviewStatus": "pending", "reviewedAt": null, "reviewedBy": null, "assignedRole": null, "adminNote": null,
         "user": {"id": 9, "email": "t@test.edu", "firstName": "Test", "lastName": "Person", "role": "member",
                  "acceptanceStatus": null},
         "reviewer": null}
        """)
        #expect(s.expectedGraduation == "2027")
        #expect(s.phone == "5550100")
        #expect(s.user?.role == "member")
        #expect(s.amsaInterests.isEmpty)
    }

    @Test func moderationPost() throws {
        let p = try Fixture.decode(ModerationPostsResponse.self, """
        {"posts": [{"id": 4, "body": "Hello", "images": [], "createdAt": "2026-09-01T10:00:00Z", "helpfulCount": 0,
                    "reviewStatus": "pending", "reviewedAt": null, "reviewNote": null,
                    "author": {"id": 2, "firstName": "A", "lastName": "B", "headline": null, "profilePic": null},
                    "reviewer": null}]}
        """)
        #expect(p.posts?.first?.author?.firstName == "A")
        #expect(p.posts?.first?.images == [])
    }

    @Test func authResponseAndStoredSessionShape() throws {
        let response = try Fixture.decode(AuthResponse.self, """
        {"message": "Login successful", "token": "a.b.c",
         "user": {"id": 1, "email": "x@y.z", "role": "admin", "roles": ["admin", "us_member"], "firstName": "X",
                  "lastName": "", "acceptanceStatus": "approved", "profilePic": null, "level": 3, "bio": null}}
        """)
        #expect(response.user.role == "admin")
        #expect(response.user.roles == ["admin", "us_member"])
        #expect(response.user.level?.value == "3")
        // Keychain item mirrors localStorage `amsa_auth`: `{ token, user }`.
        let stored = StoredSession(token: response.token, user: response.user)
        let object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(stored)) as? [String: Any])
        #expect(Set(object.keys) == ["token", "user"])
    }
}
