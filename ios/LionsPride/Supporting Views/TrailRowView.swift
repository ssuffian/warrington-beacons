/*
See LICENSE folder for this sample’s licensing information.

Abstract:
A single row to be displayed in a list of landmarks.
*/

import SwiftUI

struct TrailRowView: View {
    var landmark: Landmark
    var trail: Trail?

    init(landmark: Landmark) {
        self.landmark = landmark
        self.trail = landmarkService.getTrailById(id: landmark.id)
    }
    
    var body: some View {
        HStack {
            AsyncImage(url: getUrl("\(BASE_URL_STRING)/images/\(landmark.imageName).jpg")) { image in
                image
                    .resizable()
                    .scaledToFit().accessibility(label: Text(self.landmark.imageAlt))
            } placeholder: {
                ProgressView()
            }
            .frame(width: 75)
            VStack(alignment: .leading) {
                Text(landmark.name).modifier(LabelStyle())
                if self.trail != nil {
                    HStack {
                        Text(self.trail!.trailDistanceDescription).modifier(SmallGrayStyle())
                        Text("|").modifier(SmallGrayStyle())
                        Text("\(MapService.getLandmarksOnTrail(trail: self.trail!).count) points of interest").modifier(SmallGrayStyle())
                    }
                }
            }
            Spacer()
        }
    }
}

struct TrailRowView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            TrailRowView(landmark: landmarkService.getLandmarks()[0])
        }
        .previewLayout(.fixed(width: 300, height: 70))
    }
}
