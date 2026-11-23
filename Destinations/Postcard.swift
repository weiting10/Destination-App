//
//  Postcard.swift
//  Destinations
//
//  A sent postcard. It keeps its own copy of the photo, so it stays in the
//  gallery even if the photo or the place is deleted later.
//

import SwiftUI
import SwiftData

@Model
final class Postcard {
    /// Large binary data is kept outside the main database file.
    @Attribute(.externalStorage) var imageData: Data
    var placeName: String
    var address: String
    var sender: String
    var message: String
    var dateSent: Date

    init(imageData: Data, placeName: String, address: String, sender: String,
         message: String, dateSent: Date = .now) {
        self.imageData = imageData
        self.placeName = placeName
        self.address = address
        self.sender = sender
        self.message = message
        self.dateSent = dateSent
    }

    /// Everything the card views need to draw this postcard.
    var content: PostcardContent {
        PostcardContent(image: UIImage(data: imageData) ?? UIImage(),
                        placeName: placeName,
                        message: message,
                        sender: sender,
                        address: address,
                        date: dateSent)
    }
}

/// Plain values for drawing a card: used for saved postcards and for the live preview
/// while writing one.
struct PostcardContent {
    var image: UIImage
    var placeName: String
    var message: String
    var sender: String
    var address: String
    var date: Date
}
