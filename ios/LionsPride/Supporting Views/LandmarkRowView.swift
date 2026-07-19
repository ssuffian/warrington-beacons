/*
See LICENSE folder for this sample’s licensing information.

Abstract:
A single row to be displayed in a list of landmarks.
*/

import SwiftUI

struct LandmarkRowView: View {
    var landmark: Landmark

    var body: some View {
        HStack {
            AsyncImage(url: getUrl("\(BASE_URL_STRING)/images/\(landmark.imageName).jpg")) { image in
                image
                    .resizable().scaledToFit()
            } placeholder: {
                ProgressView()
            }
            .frame(width: 75, height: 75)
            
            VStack(alignment: .leading) {
                Text(landmark.name).modifier(LabelStyle())
                Text(landmark.description).modifier(ParagraphStyle())
            }
            Spacer()
        }
    }
}

struct LandmarkRow_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            LandmarkRowView(landmark: landmarkService.getLandmarks()[0])
            LandmarkRowView(landmark: landmarkService.getLandmarks()[1])
        }
        .previewLayout(.fixed(width: 300, height: 70))
    }
}
