//
//  Created by qubasta on 12.10.2024.
//  Copyright © 2024 qubasta. All rights reserved.
//  

import CoreMedia

protocol DecoderConfigurationRecord {
    func makeFormatDescription() -> CMFormatDescription?
}
